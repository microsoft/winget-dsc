# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

#region Functions
function Get-Pip3Path {
    if ($IsWindows) {
        # Note: When installing 64-bit version, the registry key: HKLM:\SOFTWARE\Wow6432Node\Python\PythonCore\*\InstallPath was empty.
        $userUninstallRegistry = 'HKCU:\SOFTWARE\Python\PythonCore\*\InstallPath'
        $machineUninstallRegistry = 'HKLM:\SOFTWARE\Python\PythonCore\*\InstallPath'
        $installLocationProperty = 'ExecutablePath'

        $pipExe = TryGetRegistryValue -Key $userUninstallRegistry -Property $installLocationProperty
        if ($null -ne $pipExe) {
            $userInstallLocation = Join-Path (Split-Path $pipExe -Parent) 'Scripts\pip3.exe'
            if ($userInstallLocation) {
                return $userInstallLocation
            }
        }

        $pipExe = TryGetRegistryValue -Key $machineUninstallRegistry -Property $installLocationProperty
        if ($null -ne $pipExe) {
            $machineInstallLocation = Join-Path (Split-Path $pipExe -Parent) 'Scripts\pip3.exe'
            if ($machineInstallLocation) {
                return $machineInstallLocation
            }
        }
    } elseif ($IsMacOS) {
        $pipExe = Join-Path '/Library' 'Frameworks' 'Python.framework' 'Versions' 'Current' 'bin' 'python'

        if (Test-Path -Path $pipExe) {
            return $pipExe
        }

        $pipExe = (Get-Command -Name 'pip3' -ErrorAction SilentlyContinue).Source

        if ($pipExe) {
            return $pipExe
        }
    } elseif ($IsLinux) {
        $pipExe = Join-Path '/usr/bin' 'pip3'

        if (Test-Path $pipExe) {
            return $pipExe
        }

        $pipExe = (Get-Command -Name 'pip3' -ErrorAction SilentlyContinue).Source

        if ($pipExe) {
            return $pipExe
        }
    } else {
        throw 'Operating system not supported.'
    }
}

function Assert-Pip3 {
    # Try invoking pip3 help with the alias. If it fails, switch to calling npm.cmd directly.
    # This may occur if npm is installed in the same shell window and the alias is not updated until the shell window is restarted.
    try {
        Invoke-Pip3 -command 'help'
        return
    } catch {}

    if (Test-Path -Path $global:pip3ExePath) {
        $global:usePip3Exe = $true
        Write-Verbose "Calling pip3.exe from install location: $global:usePip3Exe"
    } else {
        throw 'Python is not installed'
    }
}

function Get-PackageNameWithVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $false)]
        [string]$Arguments,

        [Parameter(Mandatory = $false)]
        [string]$Version,

        [Parameter()]
        [switch]$IsUpdate
    )

    if ($PSBoundParameters.ContainsKey('Version') -and -not ([string]::IsNullOrEmpty($Version))) {
        $packageName = $PackageName + '==' + $Version
    }

    return $packageName
}

function Invoke-Pip3Install {
    param (
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [switch]$IsUpdate
    )

    $command = [List[string]]::new()
    $command.Add('install')
    $command.Add((Get-PackageNameWithVersion @PSBoundParameters))
    if ($IsUpdate.IsPresent) {
        $command.Add('--force-reinstall')
    }
    $command.Add($Arguments)
    return Invoke-Pip3 -command $command
}

function Invoke-Pip3Uninstall {
    param (
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments,

        [Parameter()]
        [string]$Version
    )

    $command = [List[string]]::new()
    $command.Add('uninstall')
    $command.Add((Get-PackageNameWithVersion @PSBoundParameters))
    $command.Add($Arguments)

    # '--yes' is needed to ignore confirmation required for uninstalls
    $command.Add('--yes')
    return Invoke-Pip3 -command $command
}

function GetPip3CurrentState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [hashtable[]] $Package,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [hashtable] $Parameters
    )

    # Filter out the installed packages from the parameters because it is not a valid parameter when calling .ToHashTable() in the class for comparison
    if ($Parameters.ContainsKey('InstalledPackages')) {
        $Parameters.Remove('InstalledPackages')
    }

    $out = @{
        Exist             = $false
        PackageName       = $Parameters.PackageName
        Version           = $Parameters.Version
        Arguments         = $Parameters.Arguments
        InstalledPackages = $Package
    }

    foreach ($entry in $Package) {
        if ($entry.PackageName -eq $Parameters.PackageName) {
            Write-Verbose -Message "Package exist: $($entry.name)"
            $out.Exist = $true
            $out.Version = $entry.version

            if ($Parameters.ContainsKey('version') -and $entry.version -ne $Parameters.version) {
                Write-Verbose -Message "Package exist, but version is different: $($entry.version)"
                $out.Exist = $false
            }
        }
    }

    return $out
}

function GetInstalledPip3Packages {
    $Arguments = [List[string]]::new()
    $Arguments.Add('list')
    $Arguments.Add('--format=json')

    if ($global:usePip3Exe) {
        $command = "& '$global:pip3ExePath' " + $Arguments
    } else {
        $command = '& pip3 ' + $Arguments
    }

    $res = Invoke-Expression -Command $command | ConvertFrom-Json

    $result = $res | ForEach-Object {
        @{
            PackageName = $_.name
            Version     = $_.version
        }
    }

    return $result
}

function Invoke-Pip3 {
    param (
        [Parameter(Mandatory)]
        [string]$command
    )

    if ($global:usePip3Exe) {
        return Start-Process -FilePath $global:pip3ExePath -ArgumentList $command -Wait -PassThru -WindowStyle Hidden
    } else {
        return Start-Process -FilePath pip3 -ArgumentList $command -Wait -PassThru -WindowStyle hidden
    }
}

function TryGetRegistryValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Property
    )

    if (Test-Path -Path $Key) {
        try {
            return (Get-ItemProperty -Path $Key | Select-Object -ExpandProperty $Property)
        } catch {
            Write-Verbose "Property `"$($Property)`" could not be found."
        }
    } else {
        Write-Verbose 'Registry key does not exist.'
    }
}

#endregion Functions

$global:usePip3Exe = $false
$global:pip3ExePath = Get-Pip3Path

# Assert once that pip3 is already installed on the system.
Assert-Pip3

#region DSCResources
<#
.SYNOPSIS
    The `Pip3Package` DSC Resource allows you to install, update, and uninstall Python packages using pip3.

.PARAMETER SID
    The security identifier. This is a key property and should not be set manually.

.PARAMETER Exist
    Indicates whether the package should exist. Defaults to $true.

.PARAMETER Package
    The name of the Python package to manage. This is a mandatory property.

    For a list of Python packages, see https://pypi.org/.

.PARAMETER Version
    The version of the Python package to manage. If not specified, the latest version will be used.

.PARAMETER Arguments
    Additional arguments to pass to pip3.

.PARAMETER InstalledPackages
    A list of installed packages. This property is not configurable.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName PythonPip3Dsc -Name Pip3Package -Method Set -Property @{ Package = 'flask' }

    This example installs the Flask package.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName PythonPip3Dsc -Name Pip3Package -Method Get -Property @{ Package = 'flask'; Version = '1.1.4' }

    This example shows how to get the current state of the Flask package with version. If the version is not found, the latest version will be used if flask is found.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName PythonPip3Dsc -Name Pip3Package -Method Get -Property @{ Package = 'django'; Exist = $false }

    This example shows how Django can be removed from the system.
#>
[DSCResource()]
class Pip3Package {
    [DscProperty(Key, Mandatory)]
    [string]$PackageName

    [DscProperty()]
    [string]$Version

    [DscProperty()]
    [string]$Arguments

    [DscProperty()]
    [bool] $Exist = $true

    [DscProperty(NotConfigurable)]
    [hashtable[]]$InstalledPackages

    [Pip3Package] Get() {
        $this.InstalledPackages = GetInstalledPip3Packages
        $currentState = GetPip3CurrentState -Package $this.InstalledPackages -Parameters $this.ToHashTable()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($currentState.Exist -ne $this.Exist) {
            return $false
        }

        if (-not ([string]::IsNullOrEmpty($this.Version))) {
            if ($this.Version -ne $currentState.Version) {
                return $false
            }
        }

        return $true
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $currentPackage = $this.InstalledPackages | Where-Object { $_.PackageName -eq $this.PackageName }
        if ($currentPackage -and $currentPackage.Version -ne $this.Version -and $this.Exist) {
            Invoke-Pip3Install -PackageName $this.PackageName -Version $this.Version -Arguments $this.Arguments -IsUpdate
        } elseif ($this.Exist) {
            Invoke-Pip3Install -PackageName $this.PackageName -Version $this.Version -Arguments $this.Arguments
        } else {
            Invoke-Pip3Uninstall -PackageName $this.PackageName -Version $this.Version -Arguments $this.Arguments
        }
    }

    static [Pip3Package[]] Export() {
        $packages = GetInstalledPip3Packages
        $out = [List[Pip3Package]]::new()
        foreach ($package in $packages) {
            $in = [Pip3Package]@{
                PackageName       = $package.PackageName
                Version           = $package.version
                Exist             = $true
                Arguments         = $null
                InstalledPackages = $packages
            }

            $out.Add($in)
        }

        return $out
    }

    #region Pip3Package Helper functions
    [hashtable] ToHashTable() {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if (-not ([string]::IsNullOrEmpty($property.Value))) {
                $parameters[$property.Name] = $property.Value
            }
        }

        return $parameters
    }
    #endRegion Pip3Package Helper functions
}

#endregion DSCResources
