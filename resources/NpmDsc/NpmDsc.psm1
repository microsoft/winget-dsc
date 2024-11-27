using namespace System.Collections.Generic

#region Functions
function Assert-Npm {
    # Refresh session $path value before invoking 'npm'
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    try {
        Invoke-Npm -Command 'help'
        return
    } catch {
        throw 'NodeJS is not installed'
    }
}

function Invoke-Npm {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return Invoke-Expression -Command "npm $Command"
}

function Set-PackageDirectory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageDirectory
    )

    if (Test-Path -Path $PackageDirectory -PathType Container) {
        Set-Location -Path $PackageDirectory
    } else {
        throw "$($PackageDirectory) does not point to a valid directory."
    }
}

function Get-InstalledNpmPackages {
    param (
        [Parameter()]
        [bool]$Global
    )

    $command = [List[string]]::new()
    $command.Add('list')
    $command.Add('--json')

    if ($Global) {
        $command.Add('-g')
    }

    return Invoke-Npm -Command $command
}

function Install-NpmPackage {
    param (
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [bool]$Global,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add('install')
    $command.Add($PackageName)

    if ($Global) {
        $command.Add('-g')
    }

    $command.Add($Arguments)

    Write-Verbose -Message "Executing 'npm $command'"

    return Invoke-Npm -Command $command
}

function Uninstall-NpmPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter()]
        [bool]$Global,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add('uninstall')
    $command.Add($PackageName)

    if ($Global) {
        $command.Add('-g')
    }

    $command.Add($Arguments)

    Write-Verbose -Message "Executing 'npm $command'"

    return Invoke-Npm -Command $command
}

function GetNpmPath {
    if ($IsWindows) {
        $npmCacheDir = Join-Path $env:LOCALAPPDATA 'npm-cache' '_logs'
        $globalNpmCacheDir = Join-Path $env:SystemDrive 'npm' 'cache' '_logs'
        if (Test-Path $npmCacheDir -ErrorAction SilentlyContinue) {
            return $npmCacheDir
        } elseif (Test-Path $globalNpmCacheDir -ErrorAction SilentlyContinue) {
            return $globalNpmCacheDir
        } else {
            $result = (Invoke-Npm -Command 'config list --json' | ConvertFrom-Json -ErrorAction SilentlyContinue).cache
            if (Test-Path $result -ErrorAction SilentlyContinue) {
                return $result
            } else {
                return $null
            }
        }
    } elseif ($IsLinux -or $IsMacOS) {
        $npmCacheDir = Join-Path $env:HOME '.npm/_logs'
        if (Test-Path $npmCacheDir -ErrorAction SilentlyContinue) {
            return $npmCacheDir
        } else {
            return $null
        }
    } else {
        throw 'Unsupported platform'
    }
}

function GetNpmWhatIfResponse {
    $npmPath = GetNpmPath
    if ($null -ne $npmPath) {
        return (Get-NpmErrorMessages -LogPath $npmPath)
    } else {
        return @('No what-if response found.')
    }
}

function Get-NpmErrorMessages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    $lastLog = (Get-ChildItem $LogPath -Filter '*.log' | Sort-Object LastWriteTime -Descending)[0]

    Write-Verbose -Message "Found logging cache entry: $($lastLog.FullName)"

    $errorMessages = @()
    if ($lastLog) {
        $logContent = Get-Content $lastLog.FullName
        $regex = [regex]::new('^error\s.*')

        foreach ($line in $logContent) {
            $lineRemovePattern = '^\d+\s*'

            $cleanedLine = $line -replace $lineRemovePattern, ''
            if ($regex.Matches($cleanedLine)) {
                $errorMessages += $cleanedLine
            }
        }

        if ([string]::IsNullOrEmpty($errorMessages)) {
            $errorMessages = @('No what-if response found.')
        }

        return $errorMessages
    }
}
#endRegion Functions

#region Enums
enum Ensure {
    Absent
    Present
}
#endRegion Enums

#region DSCResources
[DSCResource()]
class NpmInstall {
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [bool]$Global

    [DscProperty()]
    [string]$PackageDirectory

    [DscProperty()]
    [string]$Arguments

    [NpmInstall] Get() {
        Assert-Npm

        if (-not([string]::IsNullOrEmpty($this.PackageDirectory))) {
            Set-PackageDirectory -PackageDirectory $this.PackageDirectory
        }

        $currentState = [NpmInstall]::new()
        $currentState.Ensure = [Ensure]::Present

        $errorResult = Get-InstalledNpmPackages -Global $this.Global | ConvertFrom-Json | Select-Object -ExpandProperty error
        if ($errorResult.PSobject.Properties.Name -contains 'code') {
            $errorCode = $errorResult | Select-Object -ExpandProperty code
            if ($errorCode -eq 'ELSPROBLEMS') {
                $currentState.Ensure = [Ensure]::Absent
            }
        }

        $currentState.Global = $this.Global
        $currentstate.PackageDirectory = $this.PackageDirectory
        $currentState.Arguments = $this.Arguments
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $this.Ensure -eq $currentState.Ensure
    }

    [void] Set() {
        $inDesiredState = $this.Test()
        if ($this.Ensure -eq [Ensure]::Present) {
            if (-not $inDesiredState) {
                Install-NpmPackage -Arguments $this.Arguments -Global $this.Global
            }
        } else {
            if (-not $inDesiredState) {
                $nodeModulesFolder = 'node_modules'
                if (Test-Path -Path $nodeModulesFolder) {
                    Remove-Item $nodeModulesFolder -Recurse
                }
            }
        }
    }
}

<#
.SYNOPSIS
    The `NpmPackage` DSC Resource allows you to manage the installation, update, and removal of npm packages. This resource ensures that the specified npm package is in the desired state.

.PARAMETER Ensure
    Specifies whether the npm package should be present or absent. The default value is `Present`.

.PARAMETER Name
    The name of the npm package to manage. This is a key property.

.PARAMETER Version
    The version of the npm package to install. If not specified, the latest version will be installed.

.PARAMETER PackageDirectory
    The directory where the npm package should be installed. If not specified, the package will be installed in the current directory.

.PARAMETER Global
    Indicates whether the npm package should be installed globally.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName NpmDsc -Name NpmPackage -Method Set -Property @{ Name = 'react' }

    This example installs the npm package 'react' in the current directory.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName NpmDsc -Name NpmPackage -Method Set -Property @{ Name = 'babel'; Global = $true }

    This example installs the npm package 'babel' globally.

.EXAMPLE
    PS C:\> ([NpmPackage]@{ Name = 'react' }).WhatIf()

    This example returns the whatif result for installing the npm package 'react'. Note: This does not actually install the package and requires the module to be imported using 'using module <moduleName>'.
#>
[DSCResource()]
class NpmPackage {
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$Name

    [DscProperty()]
    [string]$Version

    [DscProperty()]
    [string]$PackageDirectory

    [DscProperty()]
    [bool]$Global

    [DscProperty()]
    [string]$Arguments

    [NpmPackage] Get() {
        Assert-Npm

        if (-not([string]::IsNullOrEmpty($this.PackageDirectory))) {
            Set-PackageDirectory -PackageDirectory $this.PackageDirectory
        }

        $currentState = [NpmPackage]::new()
        $currentState.Ensure = [Ensure]::Absent

        $installedPackages = Get-InstalledNpmPackages -Global $this.Global | ConvertFrom-Json | Select-Object -ExpandProperty dependencies
        if ($installedPackages.PSobject.Properties.Name -contains $this.Name) {
            $installedPackage = $installedPackages | Select-Object -ExpandProperty $this.Name

            # Check if version matches if specified.
            if (-not([string]::IsNullOrEmpty($this.Version))) {
                $installedVersion = $installedPackage.Version
                if ([System.Version]$installedVersion -eq [System.Version]$this.Version) {
                    $currentState.Ensure = [Ensure]::Present
                }
            } else {
                $currentState.Ensure = [Ensure]::Present
            }
        }

        $currentState.Name = $this.Name
        $currentState.Version = $this.Version
        $currentState.Global = $this.Global
        $currentState.Arguments = $this.Arguments
        $currentState.PackageDirectory = $this.PackageDirectory
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $this.Ensure -eq $currentState.Ensure
    }

    [void] Set() {
        $inDesiredState = $this.Test()
        if ($this.Ensure -eq [Ensure]::Present) {
            if (-not $inDesiredState) {
                Install-NpmPackage -PackageName $this.Name -Arguments $this.Arguments -Global $this.Global
            }
        } else {
            if (-not $inDesiredState) {
                Uninstall-NpmPackage -PackageName $this.Name -Arguments $this.Arguments -Global $this.Global
            }
        }
    }

    static [NpmPackage[]] Export() {
        $packages = Get-InstalledNpmPackages -Global $true | ConvertFrom-Json -AsHashtable | Select-Object -ExpandProperty dependencies
        $out = [List[NpmPackage]]::new()
        $globalDir = (Join-Path -Path (Invoke-Npm -Command 'config get prefix') -ChildPath 'node_modules')
        foreach ($package in $packages.GetEnumerator()) {
            $in = [NpmPackage]@{
                Name             = $package.Name
                Version          = $package.Value.version
                Ensure           = [Ensure]::Present
                Global           = $true
                Arguments        = $null
                PackageDirectory = $globalDir
            }

            $out.Add($in)
        }

        return $out
    }

    [string] WhatIf() {
        if ($this.Ensure -eq [Ensure]::Present) {
            $whatIfState = Install-NpmPackage -PackageName $this.Name -Global $this.Global -Arguments '--dry-run'

            $out = @{
                Name      = $this.Name
                _metaData = @{
                    whatif = @()
                }
            }
            $out._metaData.whatif = $LASTEXITCODE -ne 0 ? (GetNpmWhatIfResponse) : ($whatIfState | Where-Object { $_.Trim() -ne '' }) # Removes empty lines from response
        } else {
            # Uninstall does not have --dry-run param
            $out = @{}
        }

        return ($out | ConvertTo-Json -Depth 10 -Compress)
    }
}
#endRegion DSCResources
