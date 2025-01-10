if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:ExplorerPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $global:CdpPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP\'
    $global:ArchiveAppPath = ('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\InstallService\Stubification\{0}\' -f ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value)
    $global:AppPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\'
    
} else {
    $global:ExplorerPath = $env:TestRegistryPath
}

#region Enums
enum AppSourcePreference {
    Anywhere
    Recommendations
    PreferStore
    StoreOnly
}

enum ShareDeviceExperience {
    Off
    Device
    Everyone
}
#endregion Enums

#region Functions
function DoesRegistryKeyPropertyExist {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    # Get-ItemProperty will return $null if the registry key property does not exist.
    $itemProperty = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $itemProperty
}

function Set-AdvancedAppSettings {
    param (
        [AppSourcePreference] $AppSourcePreference,
        [ShareDeviceExperience] $ShareDeviceExperience,
        [nullable[bool]] $ArchiveApp
    )

    if ($null -ne $AppSourcePreference) {
        if (-not (DoesRegistryKeyPropertyExist -Path $global:ExplorerPath -Name ([AdvancedAppSettings]::AppSourcePreferenceProperty))) {
            New-ItemProperty -Path $global:ExplorerPath -Name ([AdvancedAppSettings]::AppSourcePreferenceProperty) -Value $appSourcePreference -PropertyType String | Out-Null
        }
        Set-ItemProperty -Path $global:ExplorerPath -Name ([AdvancedAppSettings]::AppSourcePreferenceProperty) -Value $appSourcePreference
    }

    if ($null -ne $ShareDeviceExperience) {
        $shareDeviceExperienceValue = switch ($ShareDeviceExperience) {
            'Off' { 0 }
            'Device' { 1 }
            'Everyone' { 2 }
            default { 0 }
        }

        if (-not (DoesRegistryKeyPropertyExist -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1))) {
            New-ItemProperty -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1) -Value $shareDeviceExperienceValue -PropertyType DWord | Out-Null
        }

        if (-not (DoesRegistryKeyPropertyExist -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty2))) {
            New-ItemProperty -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty2) -Value $shareDeviceExperienceValue -PropertyType DWord | Out-Null
        }
        Set-ItemProperty -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1) -Value $shareDeviceExperienceValue
        Set-ItemProperty -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty2) -Value $shareDeviceExperienceValue
    }

    if ($null -ne $ArchiveApp) {
        if (-not (Test-Path -Path $global:ArchiveAppPath -ErrorAction SilentlyContinue)) {
            New-Item -Path $global:ArchiveAppPath -Force
        }

        if (-not (DoesRegistryKeyPropertyExist -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty))) {
            New-ItemProperty -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty) -Value ([int]$ArchiveApp) -PropertyType DWord | Out-Null
        }
        Set-ItemProperty -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty) -Value ([int]$ArchiveApp)
    }
}

function Resolve-AppXExePath {
    param(
        [Parameter(ValueFromPipeline)]
        [Alias('PSPath')]
        [string] $LiteralPath
    )
      
    process {
        $fullName = Convert-Path -LiteralPath $LiteralPath
        if (-not $?) { return }
      
        $hexDump = fsutil reparsepoint query $fullName 2>&1
        if ($LASTEXITCODE) { Throw $hexDump }
      
        [byte[]] $bytes = -split ( -join ($hexDump -match '^[a-f0-9]+:' -replace '^[a-f0-9]+:\s+(((?:[a-f0-9]{2}) +){1,16}).+$', '$1')) -replace '^', '0x'
        
        $props = [System.Text.Encoding]::Unicode.GetString($bytes) -split "`0"

        [PSCustomObject] @{
            AppId  = $props[2]
            Target = $props[3]
        } 
    }
}

function Set-AppExecutionAlias {
    param (
        [Parameter(Mandatory)]
        [string]$ExecutionAliasName,

        [Parameter(Mandatory)]
        [bool]$Exist
    )

    $windowsAppsPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    $aliasPath = Get-ChildItem -Path $windowsAppsPath -Recurse | Where-Object { $_.Name -eq $ExecutionAliasName } | Select-Object -First 1

    if ($Exist) {
        if ($aliasPath) {
            $resolvedPath = Resolve-AppXExePath -LiteralPath $aliasPath.FullName
            $appPath = "$global:AppPath\$ExecutionAliasName"
            
            if (-not (Test-Path -Path $appPath)) {
                New-Item -Path $appPath -Force | Out-Null
            }

            if (-not (DoesRegistryKeyPropertyExist -Path $appPath -Name '(Default)')) {
                New-ItemProperty -Path $appPath -Name '(Default)' -Value $resolvedPath.Target -PropertyType String | Out-Null
            } 
            Set-ItemProperty -Path $appPath -Name '(Default)' -Value $resolvedPath.Target
            
            $Parent = Split-Path -Path $resolvedPath.Target -Parent
            if (-not (DoesRegistryKeyPropertyExist -Path $appPath -Name 'Path')) {
                New-ItemProperty -Path $appPath -Name 'Path' -Value $Parent -PropertyType String | Out-Null
            }
            Set-ItemProperty -Path $appPath -Name 'Path' -Value "$Parent\"
        } else {
            Throw "Executable $ExecutionAliasName not found in $windowsAppsPath. Please install the application installer."
        }
    } else {
        $appPath = "$global:AppPath\$ExecutionAliasName"
        # Additional check to ensure that the path exists before attempting to remove it.
        if (Test-Path -Path $appPath) {
            Remove-Item -Path $appPath -Force
        }
    }
}

#endregion Functions

#region Classes
<#
.SYNOPSIS
    The `AdvancedAppSettings` DSC Resource allows you to manage advanced application settings on Windows, including app source preferences, device experience sharing, and app archiving.

.PARAMETER SID
    The security identifier. This is a key property and should not be set manually.

.PARAMETER AppSourcePreference
    Specifies the source preference for installing applications. Possible values are: Anywhere, Recommendations, PreferStore, StoreOnly.

.PARAMETER ShareDeviceExperience
    Specifies the device experience sharing setting. Possible values are: Off, Device, Everyone.

.PARAMETER ArchiveApp
    Indicates whether to enable app archiving. This is an optional parameter.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name AdvancedAppSettings -Method Set -Property @{
        AppSourcePreference = 'PreferStore';
        ShareDeviceExperience = 'Everyone';
        ArchiveApp = $true;
    }

    This example sets the advanced app settings for the specified user to prefer store apps, share device experience with everyone, and enable app archiving.
#>
[DscResource()]
class AdvancedAppSettings {
    # Key required. Do not set.
    [DscProperty(Key)] 
    [string] $SID

    [DscProperty()]
    [AppSourcePreference] $AppSourcePreference

    [DscProperty()]
    [ShareDeviceExperience] $ShareDeviceExperience

    [DscProperty()]
    [nullable[bool]] $ArchiveApp

    static hidden [string] $AppSourcePreferenceProperty = 'AicEnabled'
    static hidden [string] $ShareDeviceExperienceProperty1 = 'RomeSdkChannelUserAuthzPolicy'
    static hidden [string] $ShareDeviceExperienceProperty2 = 'CdpSessionUserAuthzPolicy'
    static hidden [string] $ArchiveAppProperty = 'EnableAppOffloading'

    [AdvancedAppSettings] Get() {
        $currentState = [AdvancedAppSettings]::new()
        $currentState.AppSourcePreference = [AdvancedAppSettings]::GetAppSourcePreference()
        $currentState.ShareDeviceExperience = [AdvancedAppSettings]::GetShareDeviceExperience()
        $currentState.ArchiveApp = [AdvancedAppSettings]::GetArchiveApp()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.AppSourcePreference) -and ($this.AppSourcePreference -ne $currentState.AppSourcePreference)) {
            return $false
        }

        if (($null -ne $this.ShareDeviceExperience) -and ($this.ShareDeviceExperience -ne $currentState.ShareDeviceExperience)) {
            return $false
        }

        if (($null -ne $this.ArchiveApp) -and ($this.ArchiveApp -ne $currentState.ArchiveApp)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            Set-AdvancedAppSettings -AppSourcePreference $this.AppSourcePreference -ShareDeviceExperience $this.ShareDeviceExperience -ArchiveApp $this.ArchiveApp
        }
    }

    #region AdvancedAppSettings helper functions
    static [AppSourcePreference] GetAppSourcePreference() {
        $preference = try {
            # Catching it this way. See issue: https://github.com/PowerShell/PowerShell/issues/5906
            Get-ItemPropertyValue -Path $global:ExplorerPath -Name ([AdvancedAppSettings]::AppSourcePreferenceProperty) -ErrorAction Stop
        } catch {
            'Anywhere'
        }
        
        return [AppSourcePreference]::$preference
    }

    static [ShareDeviceExperience] GetShareDeviceExperience() {
        # Assuming that if the first property does not exist, the second one will not exist either.
        if (-not (DoesRegistryKeyPropertyExist -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1))) {
            return [ShareDeviceExperience]::Off
        } else {
            $deviceExperience = Get-ItemPropertyValue -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1)
            $experience = switch ($deviceExperience) {
                0 { [ShareDeviceExperience]::Off }
                1 { [ShareDeviceExperience]::Device }
                2 { [ShareDeviceExperience]::Everyone }
                default { [ShareDeviceExperience]::Off }
            }

            return $experience
        }
    }

    static [bool] GetArchiveApp() {
        if (-not (DoesRegistryKeyPropertyExist -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty))) {
            return $true
        } else {
            $archiveValue = Get-ItemPropertyValue -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty)
            return ($archiveValue -eq 1)
        }
    }
}

<#
.SYNOPSIS
    The `AppExecutionAliases` DSC Resource allows you to manage execution aliases for applications on Windows.

.PARAMETER ExecutionAliasName
    The name of the execution alias. This is a key property.

.PARAMETER Exist
    Indicates whether the execution alias should exist. This is an optional parameter.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name AppExecutionAliases -Method Set -Property @{
        ExecutionAliasName = 'myAppAlias.exe';
        Exist = $true;
    }

    This example ensures that the execution alias 'myAppAlias.exe' exists.
#>
[DscResource()]
class AppExecutionAliases {
    [DscProperty(Key, Mandatory)]
    [string] $ExecutionAliasName

    [DscProperty()]
    [bool] $Exist = $true

    AppExecutionAliases () {
    }

    AppExecutionAliases ([string] $ExecutionAliasName) {
        $this.ExecutionAliasName = $ExecutionAliasName
        $this.Exist = (Test-Path -Path "$global:AppPath\$ExecutionAliasName")
    }

    [AppExecutionAliases[]] Get() {
        $currentState = [AppExecutionAliases]::new($this.ExecutionAliasName)

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($this.Exist -ne $currentState.Exist) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            Set-AppExecutionAlias -ExecutionAliasName $this.ExecutionAliasName -Exist $this.Exist
        }
    }
}
#endregion Classes
