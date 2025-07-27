# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

#region Functions
function Assert-Cargo {
    # Refresh session $path value before invoking 'cargo'
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

    if (-not (Get-Command 'cargo' -CommandType Application -ErrorAction Ignore)) {
        throw 'Cargo is not installed. Please install Rust and Cargo to use this module.'
    }
}

function Invoke-Cargo {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $out = & cargo @Arguments 2>&1 # Capture both stdout and stderr
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo command failed with exit code $LASTEXITCODE`: $out"
    }

    return $out
}

function Get-InstalledCargoCrates {
    $cargoFile = if ($IsWindows) {
        Join-Path $env:USERPROFILE -ChildPath '.cargo' '.crates2.json'
    } else {
        Join-Path -Path $HOME -ChildPath '.cargo' '.crates2.json'
    }

    $cargoInstalledPackages = [List[hashtable[]]]::new()
    if (Test-Path -Path $cargoFile) {
        if (Test-Json -Path $cargoFile) {
            $installedPackages = (Get-Content -Path $cargoFile -Raw | ConvertFrom-Json).installs
            foreach ($k in $installedPackages.psobject.properties) {
                $split = $k.Name -split ' '
                $package = @{
                    Name     = $split[0]
                    Version  = $split[1]
                    Features = @($k.Value.features)
                }
                $cargoInstalledPackages.Add($package)
            }
        }
    }

    if ($null -eq $cargoInstalledPackages -or $cargoInstalledPackages.Count -eq 0) {
        # fallback to 'cargo install --list' if .crates2.json is not available
        $result = Invoke-Cargo -Arguments @('install', '--list')

        # go through the output of 'cargo install --list'
        $lines = $result -split "`n"
        foreach ($line in $lines) {
            if ($line -match '^([^\s]+)\s+v(.+):') {
                $package = @{
                    Name     = $matches[1]
                    Version  = $matches[2]
                    Features = @()
                }
                $cargoInstalledPackages.Add($package)
            }
        }
    }

    return $cargoInstalledPackages
}

function Install-CargoCrate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CrateName,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [string[]]$Features,

        [Parameter()]
        [bool]$Force = $false
    )

    $arguments = @('install', $CrateName)

    if (-not([string]::IsNullOrEmpty($Version))) {
        $arguments += @('--version', $Version)
    }

    # Handle features
    if ($null -ne $Features -and $Features.Count -gt 0) {
        $arguments += @('--features', ($Features -join ','))
    } else {
        # If no specific features are provided, assume all features
        $arguments += '--all-features'
    }

    # Handle force flag
    if ($Force) {
        $arguments += '--force'
    }

    $arguments += '--quiet'

    Write-Verbose -Message "Executing 'cargo $($arguments -join ' ')'"

    return Invoke-Cargo -Arguments $arguments
}

function Uninstall-CargoCrate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CrateName
    )

    $arguments = @('uninstall', $CrateName)

    Write-Verbose -Message "Executing 'cargo $($arguments -join ' ')'"

    return Invoke-Cargo -Arguments $arguments
}

function Test-CrateInstalled {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CrateName,

        [Parameter()]
        [string]$Version
    )

    try {
        # Check global installation
        $installedCrates = Get-InstalledCargoCrates

        foreach ($crate in $installedCrates) {
            if ($crate.Name -eq $CrateName) {
                if ([string]::IsNullOrEmpty($Version) -or $crate.Version -eq $Version) {
                    return @{
                        Installed = $true
                        Version   = $crate.Version
                        Features  = $crate.Features
                    }
                } else {
                    return @{
                        Installed = $false
                        Version   = $crate.Version
                        Features  = $crate.Features
                    }
                }
            }
        }
    } catch {
        return @{
            Installed = $false
            Version   = $null
            Features  = @()
        }
    }
}
#endregion Functions

#region DSCResources
<#
.SYNOPSIS
    The `CargoToolInstall` DSC Resource allows you to manage the installation and removal of Rust crates using Cargo. This resource ensures that the specified Rust crate is in the desired state.

.PARAMETER Exist
    Specifies whether the Rust crate should exist (be installed) or not. The default value is $true.

.PARAMETER CrateName
    The name of the Rust crate to manage. This is a key property.

.PARAMETER Version
    The version of the Rust crate to install. If not specified, the latest version will be installed.

.PARAMETER Features
    A list of features to enable when installing the crate. If not specified, all features will be enabled using --all-features.

.PARAMETER Force
    Force overwriting existing crates or binaries. The default value is $false.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName RustDsc -Name CargoToolInstall -Method Set -Property @{ CrateName = 'bat' }

    This example installs the Rust crate 'bat' globally with all features enabled.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName RustDsc -Name CargoToolInstall -Method Set -Property @{ CrateName = 'tokio'; Version = '1.0.0' }

    This example installs the Rust crate 'tokio' version 1.0.0 globally with all features enabled.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName RustDsc -Name CargoToolInstall -Method Set -Property @{ CrateName = 'bat'; Features = @('minimal_application') }

    This example installs the Rust crate 'bat' globally with only the 'minimal_application' feature enabled.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName RustDsc -Name CargoToolInstall -Method Set -Property @{ CrateName = 'ripgrep'; Force = $true }

    This example installs the Rust crate 'ripgrep' globally with force overwriting enabled.
#>
[DSCResource()]
class CargoToolInstall {
    [DscProperty()]
    [bool]$Exist = $true

    [DscProperty(Key)]
    [string]$CrateName

    [DscProperty()]
    [string]$Version

    [DscProperty()]
    [string[]]$Features

    [DscProperty()]
    [bool]$Force = $false

    [DscProperty(NotConfigurable)]
    [string]$InstalledVersion

    [CargoToolInstall] Get() {
        Assert-Cargo

        $currentState = [CargoToolInstall]::new()
        $currentState.CrateName = $this.CrateName
        $currentState.Version = $this.Version
        $currentState.Features = $this.Features
        $currentState.Force = $this.Force

        $crateInfo = Test-CrateInstalled -CrateName $this.CrateName -Version $this.Version

        if ($null -eq $crateInfo) {
            $currentState.Exist = $false
        } else {
            $currentState.InstalledVersion = $crateInfo.Version
            $currentState.Features = $crateInfo.Features
            if (-not([string]::IsNullOrEmpty($this.Version)) -and (-not([string]::IsNullOrEmpty($crateInfo.Version)) -and ($crateInfo.Version -ne $this.Version))) {
                $currentState.Exist = $false
            } else {
                $currentState.Version = $crateInfo.Version
            }
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $this.Exist -eq $currentState.Exist
    }

    [void] Set() {
        $inDesiredState = $this.Test()

        if ($this.Exist) {
            if (-not $inDesiredState) {
                Install-CargoCrate -CrateName $this.CrateName -Version $this.Version -Features $this.Features -Force $this.Force
            }
        } else {
            if (-not $inDesiredState) {
                Uninstall-CargoCrate -CrateName $this.CrateName
            }
        }
    }

    static [CargoToolInstall[]] Export() {
        $installedCrates = Get-InstalledCargoCrates
        $out = [List[CargoToolInstall]]::new()

        foreach ($installedCrate in $installedCrates) {
            $crate = [CargoToolInstall]@{
                CrateName        = $installedCrate.Name
                Version          = $installedCrate.Version
                Features         = $installedCrate.Features
                Force            = $false  # Cannot determine force from install list
                Exist            = $true
                InstalledVersion = $installedCrate.Version
            }

            $out.Add($crate)
        }

        return $out
    }
}
#endregion DSCResources
