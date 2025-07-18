# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

#region Functions
function Assert-Cargo {
    # Refresh session $path value before invoking 'cargo'
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    try {
        $null = Invoke-Cargo -Command 'help'
    } catch {
        throw 'Rust/Cargo is not installed'
    }
}

function Invoke-Cargo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return Invoke-Expression -Command "cargo $Command"
}

function Get-InstalledCargoCrates {
    # For global crates, use 'cargo install --list'
    $result = Invoke-Cargo -Command 'install --list'
    return $result
}

function Install-CargoCrate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CrateName,

        [Parameter()]
        [string]$Version
    )

    $command = [List[string]]::new()

    # Global install
    $command.Add('install')
    $command.Add($CrateName)
    
    if (-not([string]::IsNullOrEmpty($Version))) {
        $command.Add('--version')
        $command.Add($Version)
    }

    Write-Verbose -Message "Executing 'cargo $($command -join ' ')'"

    return Invoke-Cargo -Command ($command -join ' ')
}

function Uninstall-CargoCrate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CrateName
    )

    $command = [List[string]]::new()

    # Global uninstall
    $command.Add('uninstall')
    $command.Add($CrateName)

    Write-Verbose -Message "Executing 'cargo $($command -join ' ')'"

    return Invoke-Cargo -Command ($command -join ' ')
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
        
        # Parse the output of 'cargo install --list'
        $lines = $installedCrates -split "`n"
        foreach ($line in $lines) {
            if ($line -match "^$CrateName\s+v(.+):") {
                $installedVersion = $matches[1]
                if ([string]::IsNullOrEmpty($Version) -or $installedVersion -eq $Version) {
                    return @{
                        Installed = $true
                        Version   = $installedVersion
                    }
                }
            }
        }
        
        return @{
            Installed = $false
            Version   = $null
        }
    } catch {
        return @{
            Installed = $false
            Version   = $null
        }
    }
}
#endregion Functions

#region DSCResources
<#
.SYNOPSIS
    The `CargoInstall` DSC Resource allows you to manage the installation and removal of Rust crates using Cargo. This resource ensures that the specified Rust crate is in the desired state.

.PARAMETER Exist
    Specifies whether the Rust crate should exist (be installed) or not. The default value is $true.

.PARAMETER CrateName
    The name of the Rust crate to manage. This is a key property.

.PARAMETER Version
    The version of the Rust crate to install. If not specified, the latest version will be installed.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName RustDsc -Name CargoInstall -Method Set -Property @{ CrateName = 'bat' }

    This example installs the Rust crate 'bat' globally.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName RustDsc -Name CargoInstall -Method Set -Property @{ CrateName = 'tokio'; Version = '1.0.0' }

    This example installs the Rust crate 'tokio' version 1.0.0 globally.
#>
[DSCResource()]
class CargoToolInstall {
    [DscProperty()]
    [bool]$Exist = $true

    [DscProperty(Key)]
    [string]$CrateName

    [DscProperty()]
    [string]$Version

    [DscProperty(NotConfigurable)]
    [string]$InstalledVersion

    [CargoToolInstall] Get() {
        Assert-Cargo

        $currentState = [CargoToolInstall]::new()
        $currentState.CrateName = $this.CrateName
        $currentState.Version = $this.Version
        $currentState.Exist = $false

        $crateInfo = Test-CrateInstalled -CrateName $this.CrateName -Version $this.Version
        
        if ($crateInfo.Installed) {
            $currentState.Exist = $true
            $currentState.InstalledVersion = $crateInfo.Version
            
            # Check if version matches if specified
            if (-not([string]::IsNullOrEmpty($this.Version)) -and (-not([string]::IsNullOrEmpty($crateInfo.Version)))) {
                if ($crateInfo.Version -ne $this.Version) {
                    $currentState.Exist = $false
                }
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
                Install-CargoCrate -CrateName $this.CrateName -Version $this.Version
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

        # Parse the output of 'cargo install --list'
        $lines = $installedCrates -split "`n"
        foreach ($line in $lines) {
            if ($line -match '^([^\s]+)\s+v(.+):') {
                $name = $matches[1]
                $ver = $matches[2]

                $crate = [CargoToolInstall]@{
                    CrateName        = $name
                    Version          = $ver
                    Exist            = $true
                    InstalledVersion = $ver
                }

                $out.Add($crate)
            }
        }

        return $out
    }
}
#endregion DSCResources
