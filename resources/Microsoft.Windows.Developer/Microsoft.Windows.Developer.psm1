# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

enum Ensure {
    Absent
    Present
}

enum Alignment {
    KeepCurrentValue
    Left
    Middle
}

enum ShowHideFeature {
    KeepCurrentValue
    Hide
    Show
}

enum HideTaskBarLabelsBehavior {
    KeepCurrentValue
    Always
    WhenFull
    Never
}

enum SearchBoxMode {
    KeepCurrentValue
    Hide
    ShowIconOnly
    SearchBox
    ShowIconAndLabel
}

enum AdminConsentPromptBehavior {
    KeepCurrentValue
    NoCredOrConsentRequired
    RequireCredOnSecureDesktop
    RequireConsentOnSecureDesktop
    RequireCred
    RequireConsent
    RequireConsentForNonWindowsBinaries
}

enum PowerPlanSettingName {
    DisplayTimeout
    SleepTimeout
}

enum PowerSource {
    # AC
    PluggedIn
    # DC
    Battery
    All
}

enum AdvancedNetworkSharingSettingName {
    NetworkDiscovery
    FileAndPrinterSharing
}

enum Action {
    NotConfigured
    Allow
    Block
}

enum Direction {
    Inbound
    Outbound
}

#region DSCResources
[DSCResource()]
class DeveloperMode {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty(NotConfigurable)]
    [bool] $IsEnabled

    hidden [string] $AppModelUnlockRegistryKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\'
    hidden [string] $DeveloperModePropertyName = 'AllowDevelopmentWithoutDevLicense'

    [DeveloperMode] Get() {
        function IsDeveloperModeEnabled {
            $regExists = DoesRegistryKeyPropertyExist -Path $this.AppModelUnlockRegistryKeyPath -Name $this.DeveloperModePropertyName

            # If the registry key does not exist, we assume developer mode is not enabled.
            if (-not($regExists)) {
                return $false
            }

            return Get-ItemPropertyValue -Path $this.AppModelUnlockRegistryKeyPath -Name $this.DeveloperModePropertyName
        }

        # 1 == enabled == Present // 0 == disabled == Absent
        $this.IsEnabled = IsDeveloperModeEnabled
        return @{
            Ensure    = $this.IsEnabled ? [Ensure]::Present : [Ensure]::Absent
            IsEnabled = $this.IsEnabled
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        if (!$this.Test()) {
            $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

            if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw 'Toggling Developer Mode requires this resource to be run as an Administrator.'
            }

            # 1 == enabled == Present // 0 == disabled == Absent
            $value = ($this.Ensure -eq [Ensure]::Present) ? 1 : 0
            Set-ItemProperty -Path $this.AppModelUnlockRegistryKeyPath -Name $this.DeveloperModePropertyName -Value $value
        }
    }
}

[DSCResource()]
class OsVersion {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty(Mandatory)]
    [string] $MinVersion

    [DscProperty(NotConfigurable)]
    [string] $OsVersion

    [OsVersion] Get() {
        $parsedVersion = $null
        if (![System.Version]::TryParse($this.MinVersion, [ref]$parsedVersion)) {
            throw "'$($this.MinVersion)' is not a valid Version string."
        }

        $this.OsVersion = (Get-ComputerInfo | Select-Object OsVersion).OsVersion

        return @{
            MinVersion = $this.MinVersion
            OsVersion  = $this.OsVersion
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return [System.Version]$currentState.OsVersion -ge [System.Version]$currentState.MinVersion
    }

    [void] Set() {
        # This resource is only for asserting the os version requirement.
    }
}

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:ExplorerRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'
    $global:PersonalizeRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
    $global:SearchRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\'
    $global:UACRegistryPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\'
    $global:RemoteDesktopRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $global:LongPathsRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem\'
} else {
    $global:ExplorerRegistryPath = $global:PersonalizeRegistryPath = $global:SearchRegistryPath = $global:UACRegistryPath = $global:RemoteDesktopRegistryPath = $global:LongPathsRegistryPath = $env:TestRegistryPath
}

[DSCResource()]
class Taskbar {
    [DscProperty()] [Alignment] $Alignment = [Alignment]::KeepCurrentValue
    [DscProperty()] [HideTaskBarLabelsBehavior] $HideLabelsMode = [HideTaskBarLabelsBehavior]::KeepCurrentValue
    [DscProperty()] [SearchBoxMode] $SearchboxMode = [SearchBoxMode]::KeepCurrentValue
    [DscProperty()] [ShowHideFeature] $TaskViewButton = [ShowHideFeature]::KeepCurrentValue
    [DscProperty()] [ShowHideFeature] $WidgetsButton = [ShowHideFeature]::KeepCurrentValue

    [DscProperty()] [bool] $RestartExplorer = $false
    [DscProperty(Key)] [string]$SID

    # Registry key names for the taskbar property that is being modified.
    hidden [string] $TaskbarAl = 'TaskbarAl'
    hidden [string] $TaskbarGlomLevel = 'TaskbarGlomLevel'
    hidden [string] $SearchboxTaskbarMode = 'SearchboxTaskbarMode'
    hidden [string] $ShowTaskViewButton = 'ShowTaskViewButton'
    hidden [string] $TaskbarDa = 'TaskbarDa'

    [Taskbar] Get() {
        $currentState = [Taskbar]::new()

        # Alignment
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)) {
            $currentState.Alignment = [Alignment]::Middle
        } else {
            $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)
            $currentState.Alignment = $value -eq 0 ? [Alignment]::Left : [Alignment]::Middle
        }

        # HideTaskBarLabels
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel)) {
            $currentState.HideLabelsMode = [HideTaskBarLabelsBehavior]::Always
        } else {
            $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel)
            $currentState.HideLabelsMode = switch ($value) {
                0 { [HideTaskBarLabelsBehavior]::Always }
                1 { [HideTaskBarLabelsBehavior]::WhenFull }
                2 { [HideTaskBarLabelsBehavior]::Never }
            }
        }

        # TaskbarSearchboxMode
        if (-not(DoesRegistryKeyPropertyExist -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode)) {
            $currentState.SearchboxMode = [SearchBoxMode]::SearchBox
        } else {
            $value = [int](Get-ItemPropertyValue -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode)
            $currentState.SearchboxMode = switch ($value) {
                0 { [SearchBoxMode]::Hide }
                1 { [SearchBoxMode]::ShowIconOnly }
                2 { [SearchBoxMode]::SearchBox }
                3 { [SearchBoxMode]::ShowIconAndLabel }
            }
        }

        # TaskViewButton
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton)) {
            # Default behavior if registry key not found.
            $currentState.TaskViewButton = [ShowHideFeature]::Show
        } else {
            $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton)
            $currentState.TaskViewButton = $value -eq 0 ? [ShowHideFeature]::Hide : [ShowHideFeature]::Show
        }

        # WidgetsButton
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarDa)) {
            # Default behavior if registry key not found.
            $currentState.WidgetsButton = [ShowHideFeature]::Show
        } else {
            $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarDa)
            $currentState.WidgetsButton = $value -eq 0 ? [ShowHideFeature]::Hide : [ShowHideFeature]::Show
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($this.Alignment -ne [Alignment]::KeepCurrentValue -and $currentState.Alignment -ne $this.Alignment) {
            return $false
        }

        if ($this.HideLabelsMode -ne [HideTaskBarLabelsBehavior]::KeepCurrentValue -and $currentState.HideLabelsMode -ne $this.HideLabelsMode) {
            return $false
        }

        if ($this.SearchboxMode -ne [SearchBoxMode]::KeepCurrentValue -and $currentState.SearchboxMode -ne $this.SearchboxMode) {
            return $false
        }

        if ($this.TaskViewButton -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.TaskViewButton -ne $this.TaskViewButton) {
            return $false
        }

        if ($this.WidgetsButton -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.WidgetsButton -ne $this.WidgetsButton) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.Alignment -ne [Alignment]::KeepCurrentValue) {
            $desiredAlignment = $this.Alignment -eq [Alignment]::Left ? 0 : 1
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl -Value $desiredAlignment
        }

        if ($this.HideLabelsMode -ne [HideTaskBarLabelsBehavior]::KeepCurrentValue) {
            $desiredHideLabelsBehavior = switch ($this.HideLabelsMode) {
                Always { 0 }
                WhenFull { 1 }
                Never { 2 }
            }

            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel -Value $desiredHideLabelsBehavior
        }

        if ($this.SearchboxMode -ne [SearchBoxMode]::KeepCurrentValue) {
            $desiredSearchboxMode = switch ([SearchBoxMode]($this.SearchboxMode)) {
                Hide { 0 }
                ShowIconOnly { 1 }
                SearchBox { 2 }
                ShowIconAndLabel { 3 }
            }

            Set-ItemProperty -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode -Value $desiredSearchboxMode
        }

        if ($this.TaskViewButton -ne [ShowHideFeature]::KeepCurrentValue) {
            $desiredTaskViewButtonState = $this.TaskViewButton -eq [ShowHideFeature]::Show ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton -Value $desiredTaskViewButtonState
        }

        if ($this.WidgetsButton -ne [ShowHideFeature]::KeepCurrentValue) {
            $desiredWidgetsButtonState = $this.WidgetsButton -eq [ShowHideFeature]::Show ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskBarDa -Value $desiredWidgetsButtonState
        }

        if ($this.RestartExplorer) {
            # Explorer needs to be restarted to enact the changes for HideLabelsMode.
            taskkill /F /IM explorer.exe
            Start-Process explorer.exe
        }
    }
}

[DSCResource()]
class WindowsExplorer {
    [DscProperty()] [ShowHideFeature] $FileExtensions = [ShowHideFeature]::KeepCurrentValue
    [DscProperty()] [ShowHideFeature] $HiddenFiles = [ShowHideFeature]::KeepCurrentValue
    [DscProperty()] [ShowHideFeature] $ItemCheckBoxes = [ShowHideFeature]::KeepCurrentValue

    [DscProperty()] [bool] $RestartExplorer = $false
    [DscProperty(Key)] [string]$SID

    # Registry key names for the taskbar property that is being modified.
    hidden [string] $HideFileExt = 'HideFileExt'
    hidden [string] $Hidden = 'Hidden'
    hidden [string] $AutoCheckSelect = 'AutoCheckSelect'

    [WindowsExplorer] Get() {
        $currentState = [WindowsExplorer]::new()

        # FileExtensions
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.HideFileExt)) {
            $currentState.FileExtensions = [ShowHideFeature]::Show
        } else {
            $value = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.HideFileExt
            $currentState.FileExtensions = $value -eq 1 ? [ShowHideFeature]::Hide : [ShowHideFeature]::Show
        }

        # HiddenFiles
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.Hidden)) {
            $currentState.HiddenFiles = [ShowHideFeature]::Show
        } else {
            $value = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.Hidden
            $currentState.HiddenFiles = $value -eq 1 ? [ShowHideFeature]::Show : [ShowHideFeature]::Hide
        }

        # ItemCheckboxes
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.AutoCheckSelect)) {
            $currentState.ItemCheckBoxes = [ShowHideFeature]::Show
        } else {
            $value = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.AutoCheckSelect
            $currentState.ItemCheckBoxes = $value -eq 1 ? [ShowHideFeature]::Show : [ShowHideFeature]::Hide
        }


        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($this.FileExtensions -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.FileExtensions -ne $this.FileExtensions) {
            return $false
        }

        if ($this.HiddenFiles -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.HiddenFiles -ne $this.HiddenFiles) {
            return $false
        }

        if ($this.ItemCheckBoxes -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.ItemCheckBoxes -ne $this.ItemCheckBoxes) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.FileExtensions -ne [ShowHideFeature]::KeepCurrentValue) {
            $desiredFileExtensions = $this.FileExtensions -eq [ShowHideFeature]::Show ? 0 : 1
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HideFileExt -Value $desiredFileExtensions
        }

        if ($this.HiddenFiles -ne [ShowHideFeature]::KeepCurrentValue) {
            $desiredHiddenFiles = $this.HiddenFiles -eq [ShowHideFeature]::Show ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.Hidden -Value $desiredHiddenFiles
        }

        if ($this.ItemCheckBoxes -ne [ShowHideFeature]::KeepCurrentValue) {
            $desiredItemCheckBoxes = $this.ItemCheckBoxes -eq [ShowHideFeature]::Show ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.AutoCheckSelect -Value $desiredItemCheckBoxes
        }

        if ($this.RestartExplorer) {
            # Explorer needs to be restarted to enact the changes.
            taskkill /F /IM explorer.exe
            Start-Process explorer.exe
        }
    }
}

[DSCResource()]
class UserAccessControl {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [AdminConsentPromptBehavior] $AdminConsentPromptBehavior = [AdminConsentPromptBehavior]::KeepCurrentValue

    hidden [string] $ConsentPromptBehaviorAdmin = 'ConsentPromptBehaviorAdmin'

    # NOTE: 'EnableLUA' is another registry key that disables UAC prompts, but requires a reboot and opens everything in admin mode.

    [UserAccessControl] Get() {
        $currentState = [UserAccessControl]::new()

        if (-not(DoesRegistryKeyPropertyExist -Path $global:UACRegistryPath -Name $this.ConsentPromptBehaviorAdmin)) {
            $currentState.AdminConsentPromptBehavior = [AdminConsentPromptBehavior]::RequireConsentForNonWindowsBinaries
        } else {
            $value = [int](Get-ItemPropertyValue -Path $global:UACRegistryPath -Name $this.ConsentPromptBehaviorAdmin)
            $currentState.AdminConsentPromptBehavior = switch ($value) {
                0 { [AdminConsentPromptBehavior]::NoCredOrConsentRequired }
                1 { [AdminConsentPromptBehavior]::RequireCredOnSecureDesktop }
                2 { [AdminConsentPromptBehavior]::RequireConsentOnSecureDesktop }
                3 { [AdminConsentPromptBehavior]::RequireCred }
                4 { [AdminConsentPromptBehavior]::RequireConsent }
                5 { [AdminConsentPromptBehavior]::RequireConsentForNonWindowsBinaries }
            }
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($this.AdminConsentPromptBehavior -ne [AdminConsentPromptBehavior]::KeepCurrentValue -and $currentState.AdminConsentPromptBehavior -ne $this.AdminConsentPromptBehavior) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.AdminConsentPromptBehavior -ne [AdminConsentPromptBehavior]::KeepCurrentValue) {
            $desiredState = switch ([AdminConsentPromptBehavior]($this.AdminConsentPromptBehavior)) {
                NoCredOrConsentRequired { 0 }
                RequireCredOnSecureDesktop { 1 }
                RequireConsentOnSecureDesktop { 2 }
                RequireCred { 3 }
                RequireConsent { 4 }
                RequireConsentForNonWindowsBinaries { 5 }
            }

            Set-ItemProperty -Path $global:UACRegistryPath -Name $this.ConsentPromptBehaviorAdmin -Value $desiredState
        }
    }
}

[DSCResource()]
class EnableDarkMode {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty()]
    [bool] $RestartExplorer = $false

    hidden [string] $AppsUseLightTheme = 'AppsUseLightTheme'
    hidden [string] $SystemUsesLightTheme = 'SystemUsesLightTheme'

    [EnableDarkMode] Get() {
        $exists = (DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme) -and (DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme)
        if (-not($exists)) {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $appsUseLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme
        $systemUsesLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme

        $isDarkModeEnabled = if ($appsUseLightModeValue -eq 0 -and $systemUsesLightModeValue -eq 0) { [Ensure]::Present } else { [Ensure]::Absent }

        return @{
            Ensure = $isDarkModeEnabled
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        $value = if ($this.Ensure -eq [Ensure]::Present) { 0 } else { 1 }
        Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme -Value $value
        Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme -Value $value

        if ($this.RestartExplorer) {
            # Explorer needs to be restarted to enact the changes.
            Stop-Process -ProcessName Explorer
        }
    }
}

[DSCResource()]
class ShowSecondsInClock {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    hidden [string] $ShowSecondsInSystemClock = 'ShowSecondsInSystemClock'

    [ShowSecondsInClock] Get() {
        $exists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.ShowSecondsInSystemClock
        if (-not($exists)) {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.ShowSecondsInSystemClock

        return @{
            Ensure = $registryValue ? [Ensure]::Present : [Ensure]::Absent
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        $value = ($this.Ensure -eq [Ensure]::Present) ? 1 : 0
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.ShowSecondsInSystemClock -Value $value
    }
}

[DSCResource()]
class EnableRemoteDesktop {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    hidden [string] $RemoteDesktopKey = 'fDenyTSConnections'

    [EnableRemoteDesktop] Get() {
        $exists = DoesRegistryKeyPropertyExist -Path $global:RemoteDesktopRegistryPath -Name $this.RemoteDesktopKey
        if (-not($exists)) {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $registryValue = Get-ItemPropertyValue -Path $global:RemoteDesktopRegistryPath -Name $this.RemoteDesktopKey

        # Since the key is a 'deny' type key, 0 == enabled == Present // 1 == disabled == Absent
        return @{
            Ensure = $registryValue ? [Ensure]::Absent : [Ensure]::Present
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        # Since the key is a 'deny' type key, 0 == enabled == Present // 1 == disabled == Absent
        $value = ($this.Ensure -eq [Ensure]::Present) ? 0 : 1
        Set-ItemProperty -Path $global:RemoteDesktopRegistryPath -Name $this.RemoteDesktopKey -Value $value
    }
}

[DSCResource()]
class EnableLongPathSupport {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    hidden [string] $LongPathsKey = 'LongPathsEnabled'

    [EnableLongPathSupport] Get() {
        $exists = DoesRegistryKeyPropertyExist -Path $global:LongPathsRegistryPath -Name $this.LongPathsKey

        # If the registry key does not exist, we assume long path support is not enabled.
        if (-not($exists)) {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $registryValue = Get-ItemPropertyValue -Path $global:LongPathsRegistryPath -Name $this.LongPathsKey

        # 1 == enabled == Present // 0 == disabled == Absent
        return @{
            Ensure = $registryValue ? [Ensure]::Present : [Ensure]::Absent
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        # 1 == enabled == Present // 0 == disabled == Absent
        $value = ($this.Ensure -eq [Ensure]::Present) ? 1 : 0
        Set-ItemProperty -Path $global:LongPathsRegistryPath -Name $this.LongPathsKey -Value $value
    }
}

[DSCResource()]
class PowerPlanSetting {
    [DscProperty(Key, Mandatory)]
    [PowerPlanSettingName]$Name

    [DscProperty(Mandatory)]
    [PowerSource]$PowerSource

    [DscProperty(Mandatory)]
    [int]$SettingValue

    [DscProperty(NotConfigurable)]
    [int] $PluggedInValue

    [DscProperty(NotConfigurable)]
    [int] $BatteryValue

    [PowerPlanSetting] Get() {

        function Get-PowerPlanSetting ([PowerPlanSettingName] $SettingName) {
            Begin {
                # If a power plan group policy is set, the power settings cannot be obtained, so temporarily disable it.
                $GPReg = Backup-GroupPolicyPowerPlanSetting
                if ($GPReg) {
                    Disable-GroupPolicyPowerPlanSetting
                }
            }

            Process {
                $SettingGUID = ($SettingName -eq [PowerPlanSettingName]::DisplayTimeout) ? $DisplayTimeoutSettingGUID : $SleepTimeoutSettingGUID
                $PowerPlan = Get-ActivePowerPlan
                $planID = $PowerPlan.InstanceId.Split('\')[1] -replace '[{}]'

                $ReturnValue = @{
                    PlanGuid    = $planID
                    SettingGuid = $SettingGUID
                    ACValue     = ''
                    DCValue     = ''
                }

                foreach ($Power in ('AC', 'DC')) {
                    $Key = ('{0}Value' -f $Power)
                    $InstanceId = ('Microsoft:PowerSettingDataIndex\{{{0}}}\{1}\{{{2}}}' -f $planID, $Power, $SettingGUID)
                    $Instance = (Get-CimInstance -Name root\cimv2\power -Class Win32_PowerSettingDataIndex | Where-Object { $_.InstanceID -eq $InstanceId })
                    # error state
                    if (-not $Instance) { return }
                    $ReturnValue.$Key = [int]$Instance.SettingIndexValue
                }

                return $ReturnValue
            }

            End {
                if ($GPReg) {
                    # Restore the group policies
                    Restore-GroupPolicyPowerPlanSetting -GPRegArray $GPReg
                }
            }
        }

        $Setting = Get-PowerPlanSetting -SettingName $this.Name
        $this.PluggedInValue = $Setting.ACValue
        $this.BatteryValue = $Setting.DCValue

        $currentState = [PowerPlanSetting]::new()
        $currentState.Name = $this.Name
        $currentState.SettingValue = $this.SettingValue
        $currentState.PluggedInValue = $this.PluggedInValue
        $currentState.BatteryValue = $this.BatteryValue
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        # User can only specify a single setting value
        $pluggedInTest = ($currentState.PluggedInValue -eq $this.SettingValue)
        $batteryTest = ($currentState.BatteryValue -eq $this.SettingValue)

        if ($this.PowerSource -eq [PowerSource]::All) {
            return ($pluggedInTest -and $batteryTest)
        } elseif ($this.PowerSource -eq [PowerSource]::PluggedIn) {
            return $pluggedInTest
        } else {
            return $batteryTest
        }
    }

    [void] Set() {
        function Set-PowerPlanSetting ([PowerPlanSettingName] $PowerPlanSettingName, [PowerSource]$PowerSource, [int]$Value) {
            Begin {
                # If a power plan group policy is set, the power settings cannot be obtained, so temporarily disable it.
                $GPReg = Backup-GroupPolicyPowerPlanSetting
                if ($GPReg) {
                    Disable-GroupPolicyPowerPlanSetting
                }
            }
            Process {
                $SettingGUID = ($PowerPlanSettingName -eq [PowerPlanSettingName]::DisplayTimeout) ? $DisplayTimeoutSettingGUID : $SleepTimeoutSettingGUID
                $PowerPlan = Get-ActivePowerPlan
                $planID = $PowerPlan.InstanceId.Split('\')[1] -replace '[{}]'

                if ($PowerSource -eq [PowerSource]::All) {
                    [string[]]$Target = ('AC', 'DC')
                } elseif ($PowerSource -eq [PowerSource]::PluggedIn) {
                    [string[]]$Target = ('AC')
                } else {
                    [string[]]$Target = ('DC')
                }

                foreach ($Power in $Target) {
                    $InstanceId = ('Microsoft:PowerSettingDataIndex\{{{0}}}\{1}\{{{2}}}' -f $planID, $Power, $SettingGUID)
                    $Instance = Get-CimInstance -Name root\cimv2\power -Class Win32_PowerSettingDataIndex | Where-Object { $_.InstanceID -eq $InstanceId }
                    # error state
                    if (-not $Instance) { return }
                    $Instance | ForEach-Object { $_.SettingIndexValue = $Value }
                    Set-CimInstance -CimInstance $Instance
                }
            }
            End {
                if ($GPReg) {
                    # Restore the group policies
                    Restore-GroupPolicyPowerPlanSetting -GPRegArray $GPReg
                }
            }
        }

        if (!$this.Test()) {
            Set-PowerPlanSetting -PowerPlanSettingName $this.Name -PowerSource $this.PowerSource -Value $this.SettingValue
        }
    }
}

[DSCResource()]
class WindowsCapability {
    [DscProperty(Key, Mandatory)]
    [string] $Name

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [WindowsCapability] Get() {
        $currentState = [WindowsCapability]::new()
        $windowsCapability = Get-WindowsCapability -Online -Name $this.Name

        # If Name is not set in windowsCapability then the specified capability was not found
        if ([System.String]::IsNullOrEmpty($windowsCapability.Name)) {
            throw  (New-Object -TypeName System.ArgumentException -ArgumentList "$this.Name")
        } else {
            $currentState.Name = $windowsCapability.Name

            if ($windowsCapability.State -eq 'Installed') {
                $currentState.Ensure = [Ensure]::Present
            } else {
                $currentState.Ensure = [Ensure]::Absent
            }
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        # Only make changes if changes are needed
        if (-not $this.Test()) {
            if ($this.Ensure -eq [Ensure]::Present) {
                Add-WindowsCapability -Online -Name $this.Name
            } else {
                Remove-WindowsCapability -Online -Name $this.Name
            }
        }
    }
}

[DSCResource()]
class NetConnectionProfile {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty(Mandatory)]
    [string]$InterfaceAlias

    [DscProperty(Mandatory)]
    [string]$NetworkCategory

    [NetConnectionProfile] Get() {
        $currentState = [NetConnectionProfile]::new()

        $netConnectionProfile = Get-NetConnectionProfile -InterfaceAlias $this.InterfaceAlias -ErrorAction SilentlyContinue
        if ($null -eq $netConnectionProfile) {
            throw "No network profile found for interface alias '$($this.InterfaceAlias)'"
        }

        $currentState.InterfaceAlias = $this.InterfaceAlias
        $currentState.NetworkCategory = $netConnectionProfile.NetworkCategory
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.NetworkCategory -eq $this.NetworkCategory
    }

    [void] Set() {
        if (-not $this.Test()) {
            Set-NetConnectionProfile -InterfaceAlias $this.InterfaceAlias -NetworkCategory $this.NetworkCategory
        }
    }
}

[DSCResource()]
class AdvancedNetworkSharingSetting {
    [DscProperty(Key, Mandatory)]
    [AdvancedNetworkSharingSettingName]$Name

    [DscProperty()]
    [string[]]$Profiles = @()

    [DscProperty(NotConfigurable)]
    [string[]]$EnabledProfiles

    # Official group names for the firewall rules
    hidden [string] $NetworkDiscoveryGroup = '@FirewallAPI.dll,-32752'
    hidden [string] $FileAndPrinterSharingGroup = '@FirewallAPI.dll,-28502'

    [AdvancedNetworkSharingSetting] Get() {
        $currentState = [AdvancedNetworkSharingSetting]::new()
        $currentState.Name = $this.Name
        $currentState.Profiles = $this.Profiles

        if ($this.Name -eq [AdvancedNetworkSharingSettingName]::NetworkDiscovery) {
            $group = $this.NetworkDiscoveryGroup
        } else {
            $group = $this.FileAndPrinterSharingGroup
        }

        # The group is enabled if all of its sub-rules are enabled and none are disabled.
        $this.EnabledProfiles = Get-NetFirewallRule -Group $group | Group-Object Profile | ForEach-Object {
            $enabled = ($_.Group.Enabled | Where-Object { $_ -eq 'true' } | Measure-Object).Count
            $disabled = ($_.Group.Enabled | Where-Object { $_ -eq 'false' } | Measure-Object).Count
            [PSCustomObject]@{
                Profile  = $_.Name
                Count    = $_.Count
                Enabled  = $enabled
                Disabled = $disabled
            }
        } | Where-Object { ($_.Enabled -gt 0) -and ($_.Disabled -eq 0) -and ($_.Enabled -eq $_.Count) } | Select-Object -Unique -CaseInsensitive -ExpandProperty Profile

        $currentState.EnabledProfiles = $this.EnabledProfiles

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        # Compare-object is case insensitive by default and does not take null arguments
        $difference = Compare-Object -ReferenceObject @( $this.Profiles | Select-Object) -DifferenceObject @( $currentState.EnabledProfiles | Select-Object)
        return -not $difference
    }

    [void] Set() {
        if (!$this.Test()) {
            if ($this.Name -eq [AdvancedNetworkSharingSettingName]::NetworkDiscovery) {
                $group = $this.NetworkDiscoveryGroup
            } else {
                $group = $this.FileAndPrinterSharingGroup
            }

            #Enable, no harm in enabling profiles if they are already enabled
            foreach ($profile in $this.Profiles) {
                Set-NetFirewallRule -Group $group -Profile $profile -Enabled True
            }

            #Disable needed if at least one profile is enabled
            $profilesToDisable = Get-NetFirewallRule -Group $group | Where-Object { ($_.Enabled -eq 'True') -and (-not $this.Profiles -Contains $_.Profile ) } | Select-Object -Unique -CaseInsensitive -ExpandProperty Profile
            foreach ($profile in $profilesToDisable) {
                Set-NetFirewallRule -Group $group -Profile $profile -Enabled False
            }
        }
    }
}

[DSCResource()]
class FirewallRule {
    [DscProperty(Key, Mandatory)]
    [string]$Name

    [DscProperty()]
    [string]$DisplayName

    [DscProperty()]
    [Action]$Action

    [DscProperty()]
    [string]$Description

    [DscProperty()]
    [Direction]$Direction

    [DscProperty()]
    [bool]$Enabled

    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty()]
    [string[]]$LocalPort

    [DscProperty()]
    [string[]]$Profiles

    [DscProperty()]
    [string]$Protocol

    [FirewallRule] Get() {
        $rule = Get-NetFirewallRule -Name $this.Name -ErrorAction SilentlyContinue

        if (-not $rule) {
            return @{
                Ensure = [Ensure]::Absent
                Name   = $this.Name
            }
        }

        $properties = $rule | GetNetFirewallPortFilter
        return @{
            Ensure      = [Ensure]::Present
            Name        = $rule.Name
            DisplayName = $rule.DisplayName
            Action      = $rule.Action
            Description = $rule.Description
            Direction   = $rule.Direction
            Enabled     = $rule.Enabled
            LocalPort   = $properties.LocalPort
            # Split the profiles string into an array
            Profiles    = ($rule.Profile -split ',') | ForEach-Object { $_.Trim() }
            Protocol    = $properties.Protocol
        }
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($this.Ensure -eq [Ensure]::Absent) {
            return $currentState.Ensure -eq [Ensure]::Absent
        }

        # Check each property only if it is specified
        if ($this.DisplayName -and ($currentState.DisplayName -ne $this.DisplayName)) {
            return $false
        }

        if ($currentState.Action -ne $this.Action) {
            return $false
        }

        if ($this.Description -and ($currentState.Description -ne $this.Description)) {
            return $false
        }

        if ($currentState.Direction -ne $this.Direction) {
            return $false
        }

        if ($currentState.Enabled -ne $this.Enabled) {
            return $false
        }

        if ($this.LocalPort -and (Compare-Object $currentState.LocalPort $this.LocalPort)) {
            return $false
        }

        if ($this.Profiles -and (Compare-Object $currentState.Profiles $this.Profiles)) {
            return $false
        }

        if ($this.Protocol -and ($currentState.Protocol -ne $this.Protocol)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        # Only make changes if changes are needed
        if (-not $this.Test()) {
            if ($this.Ensure -eq [Ensure]::Absent) {
                Remove-NetFirewallRule -Name $this.Name -ErrorAction SilentlyContinue
            } else {
                $firewallRule = Get-NetFirewallRule -Name $this.Name
                $exists = ($null -ne $firewallRule)

                $params = @{
                    # Escape firewall rule name to ensure that wildcard update is not used
                    Name        = ConvertTo-FirewallRuleNameEscapedString -Name $this.Name
                    DisplayName = $this.DisplayName
                    Action      = $this.Action.ToString()
                    Description = $this.Description
                    Direction   = $this.Direction.ToString()
                    Enabled     = $this.Enabled.ToString()
                    Profile     = $this.Profiles
                    Protocol    = $this.Protocol
                    LocalPort   = $this.LocalPort
                }

                if ($exists) {
                    <#
                        If the DisplayName is provided then need to remove it
                        And change it to NewDisplayName if it is different.
                    #>
                    if ($params.ContainsKey('DisplayName')) {
                        $null = $params.Remove('DisplayName')
                        if ($this.DisplayName -ne $FirewallRule.DisplayName) {
                            $null = $params.Add('NewDisplayName', $this.DisplayName)
                        }
                    }

                    Set-NetFirewallRule @params
                } else {
                    New-NetFirewallRule @params
                }
            }
        }
    }
}
#endregion DSCResources

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

function Get-ActivePowerPlan {
    Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan | Where-Object { $_.IsActive }
}

$SleepTimeoutSettingGUID = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
$DisplayTimeoutSettingGUID = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'

$GroupPolicyPowerPlanRegistryKeyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings'

function Backup-GroupPolicyPowerPlanSetting {
    if (Test-Path $GroupPolicyPowerPlanRegistryKeyPath) {
        $Array = @()
        Get-ChildItem $GroupPolicyPowerPlanRegistryKeyPath | ForEach-Object {
            $Path = $_.PSPath
            foreach ($Prop in $_.Property) {
                $Array += @{
                    Path  = $Path
                    Name  = $Prop
                    Value = Get-ItemPropertyValue -Path $Path -Name $Prop
                }
            }
        }
        $Array
    }
}

function Restore-GroupPolicyPowerPlanSetting([HashTable[]]$GPRegArray) {
    foreach ($Item in $GPRegArray) {
        if (-not (Test-Path $Item.Path)) {
            New-Item -Path $Item.Path -ItemType Directory -Force | Out-Null
        }
        New-ItemProperty @Item -Force | Out-Null
    }
}

function Disable-GroupPolicyPowerPlanSetting {
    Remove-Item $GroupPolicyPowerPlanRegistryKeyPath -Recurse -Force | Out-Null
}

# Convert Firewall Rule name to Escape Wildcard Characters. It will append '[', ']' and '*' with a backtick.
function ConvertTo-FirewallRuleNameEscapedString {
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Name
    )

    return $Name.Replace('[', '`[').Replace(']', '`]').Replace('*', '`*')
}

# Workaround mock issue for Get-NetFirewallPortFilter
function GetNetFirewallPortFilter {
    process {
        return $_ | Get-NetFirewallPortFilter
    }
}
#endregion Functions
