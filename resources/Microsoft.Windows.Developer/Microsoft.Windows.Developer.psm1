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

    [DeveloperMode] Get() {
        $this.IsEnabled = IsDeveloperModeEnabled

        return @{
            Ensure    = $this.Ensure
            IsEnabled = $this.IsEnabled
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($currentState.Ensure -eq [Ensure]::Present) {
            return $currentState.IsEnabled
        } else {
            return $currentState.IsEnabled -eq $false
        }
    }

    [void] Set() {
        if (!$this.Test()) {
            $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

            if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw 'Toggling Developer Mode requires this resource to be run as an Administrator.'
            }

            $shouldEnable = $this.Ensure -eq [Ensure]::Present
            SetDeveloperMode -Enable $shouldEnable
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
} else {
    $global:ExplorerRegistryPath = $global:PersonalizeRegistryPath = $global:SearchRegistryPath = $global:UACRegistryPath = $global:RemoteDesktopRegistryPath = $env:TestRegistryPath
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
#endregion DSCResources

#region Functions
$AppModelUnlockRegistryKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\'
$DeveloperModePropertyName = 'AllowDevelopmentWithoutDevLicense'

function IsDeveloperModeEnabled {
    try {
        $property = Get-ItemProperty -Path $AppModelUnlockRegistryKeyPath -Name $DeveloperModePropertyName
        return $property.AllowDevelopmentWithoutDevLicense -eq 1
    } catch {
        # This will throw an exception if the registry path or property does not exist.
        return $false
    }
}

function SetDeveloperMode {
    param (
        [Parameter(Mandatory)]
        [bool]$Enable
    )

    if (-not (Test-Path -Path $AppModelUnlockRegistryKeyPath)) {
        New-Item -Path $AppModelUnlockRegistryKeyPath -Force | Out-Null
    }

    $developerModeValue = [int]$Enable
    New-ItemProperty -Path $AppModelUnlockRegistryKeyPath -Name $DeveloperModePropertyName -Value $developerModeValue -PropertyType DWORD -Force | Out-Null
}

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

#endregion Functions
