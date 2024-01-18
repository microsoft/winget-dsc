# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

enum Ensure
{
    Absent
    Present
}

enum Alignment
{
    KeepCurrentValue
    Left = 0
    Middle = 1
}

enum ShowHideFeature
{
    KeepCurrentValue
    Hide = 0
    Show = 1
}

enum HideTaskBarLabelsBehavior
{
    KeepCurrentValue
    Always = 0
    WhenFull = 1
    Never = 2
}

enum TaskbarSearchBoxMode {
    KeepCurrentValue
    Hide = 0
    ShowIconOnly = 1
    SearchBox = 2
    ShowIconAndLabel = 3
}

#region DSCResources
[DSCResource()]
class DeveloperMode
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty(NotConfigurable)]
    [bool] $IsEnabled

    [DeveloperMode] Get()
    {
        $this.IsEnabled = IsDeveloperModeEnabled

        return @{
            Ensure = $this.Ensure
            IsEnabled = $this.IsEnabled
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        if ($currentState.Ensure -eq [Ensure]::Present)
        {
            return $currentState.IsEnabled
        }
        else
        {
            return $currentState.IsEnabled -eq $false
        }
    }

    [void] Set()
    {
        if (!$this.Test())
        {
            $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )
        
            if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
            {
                throw "Toggling Developer Mode requires this resource to be run as an Administrator."
            }

            $shouldEnable = $this.Ensure -eq [Ensure]::Present
            SetDeveloperMode -Enable $shouldEnable
        }
    }

}

[DSCResource()]
class OsVersion
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty(Mandatory)]
    [string] $MinVersion

    [DscProperty(NotConfigurable)]
    [string] $OsVersion

    [OsVersion] Get()
    {
        $parsedVersion = $null
        if (![System.Version]::TryParse($this.MinVersion, [ref]$parsedVersion))
        {
            throw "'$($this.MinVersion)' is not a valid Version string."
        }

        $this.OsVersion = (Get-ComputerInfo | Select-Object OsVersion).OsVersion

        return @{
            MinVersion = $this.MinVersion
            OsVersion = $this.OsVersion
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return [System.Version]$currentState.OsVersion -ge [System.Version]$currentState.MinVersion
    }

    [void] Set()
    {
        # This resource is only for asserting the os version requirement.
    }

}

$global:ExplorerRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'
$global:PersonalizeRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
$global:SearchRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\'
$global:UACRegistryPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\'

[DSCResource()]
class Taskbar
{
    [DscProperty()] [Alignment] $Alignment = [Alignment]::KeepCurrentValue
    [DscProperty()] [HideTaskBarLabelsBehavior] $HideLabelsMode = [HideTaskBarLabelsBehavior]::KeepCurrentValue
    [DscProperty()] [TaskbarSearchboxMode] $SearchboxMode = [TaskbarSearchboxMode]::KeepCurrentValue
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

    [Taskbar] Get()
    {
        $currentState = [Taskbar]::new()

        # Alignment
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl))
        {
            $currentState.Alignment = [Alignment]::Middle
        }
        else
        {
            $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)
            $currentState.Alignment = $value -eq 0 ? [Alignment]::Left : [Alignment]::Middle
        }

        # HideTaskBarLabels
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel))
        {
            $currentState.HideLabelsMode = [HideTaskBarLabelsBehavior]::Always
        }
        else
        {
            $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel)
            $currentState.HideLabelsMode = switch ($value)
            {
                0 { [HideTaskBarLabelsBehavior]::Always }
                1 { [HideTaskBarLabelsBehavior]::WhenFull }
                2 { [HideTaskBarLabelsBehavior]::Never }
            }
        }

        # TaskbarSearchboxMode
        if (-not(DoesRegistryKeyPropertyExist -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode))
        {
            $currentState.SearchboxMode = [TaskbarSearchBoxMode]::SearchBox
        }
        else
        {
            $value = [int](Get-ItemPropertyValue -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode)
            $currentState.HideLabelsMode = switch ($value)
            {
                0 { [TaskbarSearchBoxMode]::Hide }
                1 { [TaskbarSearchBoxMode]::ShowIconOnly }
                2 { [TaskbarSearchBoxMode]::SearchBox }
                3 { [TaskbarSearchBoxMode]::ShowIconAndLabel }
            }
        }

        # TaskViewButton
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton))
        {
            # Default behavior if registry key not found.
            $currentState.TaskViewButton = [ShowHideFeature]::Show
        }
        else
        {
            $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton)
            $currentState.TaskViewButton = $value -eq 0 ? [ShowHideFeature]::Hide : [ShowHideFeature]::Show
        }

        # WidgetsButton
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarDa))
        {
            # Default behavior if registry key not found.
            $currentState.WidgetsButton = [ShowHideFeature]::Show
        }
        else
        {
            $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarDa)
            $currentState.WidgetsButton = $value -eq 0 ? [ShowHideFeature]::Hide : [ShowHideFeature]::Show
        }

        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        
        if ($this.Alignment -ne [Alignment]::KeepCurrentValue -and $currentState.Alignment -ne $this.Alignment)
        {
            return $false
        }

        if ($this.HideLabelsMode -ne [HideTaskBarLabelsBehavior]::KeepCurrentValue -and $currentState.HideLabelsMode -ne $this.HideLabelsMode)
        {
            return $false
        }

        if ($this.SearchboxMode -ne [TaskbarSearchBoxMode]::KeepCurrentValue -and $currentState.SearchboxMode -ne $this.SearchboxMode)
        {
            return $false
        }

        if ($this.TaskViewButton -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.TaskViewButton -ne $this.TaskViewButton)
        {
            return $false
        }

        if ($this.WidgetsButton -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.WidgetsButton -ne $this.WidgetsButton)
        {
            return $false
        }

        return $true
    }

    [void] Set()
    {
        if ($this.Alignment -ne [Alignment]::KeepCurrentValue)
        {
            $desiredAlignment = $this.Alignment -eq [Alignment]::Left ? 0 : 1
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl -Value $desiredAlignment
        }

        if ($this.HideLabelsMode -ne [HideTaskBarLabelsBehavior]::KeepCurrentValue)
        {
            $desiredHideLabelsBehavior = switch ($this.HideLabelsMode)
            {
                [HideTaskBarLabelsBehavior]::Always { 0 }
                [HideTaskBarLabelsBehavior]::WhenFull { 1 }
                [HideTaskBarLabelsBehavior]::Never { 2 }
            }

            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel -Value $desiredHideLabelsBehavior

            if ($this.RestartExplorer)
            {
                # Explorer needs to be restarted to enact the changes.
                taskkill /F /IM explorer.exe
                Start-Process explorer.exe
            }
        }

        if ($this.SearchboxMode -ne [TaskbarSearchBoxMode]::KeepCurrentValue)
        {
            $desiredSearchboxMode = switch ($this.HideLabelsMode)
            {
                [TaskbarSearchBoxMode]::Hide { 0 }
                [TaskbarSearchBoxMode]::ShowIconOnly { 1 }
                [TaskbarSearchBoxMode]::SearchBox { 2 }
                [TaskbarSearchBoxMode]::ShowIconAndLabel { 3 }
            }

            Set-ItemProperty -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode -Value $desiredSearchboxMode
        }

        if ($this.TaskViewButton -ne [ShowHideFeature]::KeepCurrentValue)
        {
            $desiredTaskViewButtonState = $this.WidgetsButton -eq [ShowHideFeature]::Show ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton -Value $desiredTaskViewButtonState
        }

        if ($this.WidgetsButton -ne [ShowHideFeature]::KeepCurrentValue)
        {
            $desiredWidgetsButtonState = $this.WidgetsButton -eq [ShowHideFeature]::Show ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskBarDa -Value $desiredWidgetsButtonState
        }
    }
}

[DSCResource()]
class WindowsExplorer
{
    [DscProperty()] [ShowHideFeature] $FileExtensions = [ShowHideFeature]::KeepCurrentValue
    [DscProperty()] [ShowHideFeature] $HiddenFiles = [ShowHideFeature]::KeepCurrentValue
    [DscProperty()] [ShowHideFeature] $ItemCheckBoxes = [ShowHideFeature]::KeepCurrentValue

    [DscProperty()] [bool] $RestartExplorer = $false
    [DscProperty(Key)] [string]$SID

    # Registry key names for the taskbar property that is being modified.
    hidden [string] $HideFileExt = 'HideFileExt'
    hidden [string] $Hidden = 'Hidden'
    hidden [string] $AutoCheckSelect = 'AutoCheckSelect'

    [WindowsExplorer] Get()
    {
        $currentState = [WindowsExplorer]::new()

        # FileExtensions
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.HideFileExt))
        {
            $currentState.FileExtensions = [ShowHideFeature]::Show
        }
        else
        {
            $value = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.HideFileExt
            $currentState.FileExtensions = $value -eq 1 ? [ShowHideFeature]::Hide : [ShowHideFeature]::Show
        }

        # HiddenFiles
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.Hidden))
        {
            $currentState.HiddenFiles = [ShowHideFeature]::Show
        }
        else
        {
            $value = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.Hidden
            $currentState.HiddenFiles = $value -eq 1 ? [ShowHideFeature]::Hide : [ShowHideFeature]::Show
        }

        # ItemCheckboxes
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.AutoCheckSelect))
        {
            $currentState.ItemCheckBoxes = [ShowHideFeature]::Show
        }
        else
        {
            $value = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.AutoCheckSelect
            $currentState.ItemCheckBoxes = $value -eq 1 ? [ShowHideFeature]::Hide : [ShowHideFeature]::Show
        }


        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        
        if ($this.FileExtensions -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.FileExtensions -ne $this.FileExtensions)
        {
            return $false
        }

        if ($this.HiddenFiles -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.HiddenFiles -ne $this.HiddenFiles)
        {
            return $false
        }

        if ($this.ItemCheckBoxes -ne [ShowHideFeature]::KeepCurrentValue -and $currentState.ItemCheckBoxes -ne $this.ItemCheckBoxes)
        {
            return $false
        }

        return $true
    }

    [void] Set()
    {
        if ($this.FileExtensions -ne [ShowHideFeature]::KeepCurrentValue)
        {
            $desiredFileExtensions = $this.FileExtensions -eq [ShowHideFeature]::Hide ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskBarDa -Value $desiredFileExtensions
        }

        if ($this.HiddenFiles -ne [ShowHideFeature]::KeepCurrentValue)
        {
            $desiredHiddenFiles = $this.HiddenFiles -eq [ShowHideFeature]::Show ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HiddenFiles -Value $desiredHiddenFiles
        }

        if ($this.ItemCheckBoxes -ne [ShowHideFeature]::KeepCurrentValue)
        {
            $desiredItemCheckBoxes = $this.ItemCheckBoxes -eq [ShowHideFeature]::Show ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HideFileExt -Value $desiredItemCheckBoxes
        }

        if ($this.RestartExplorer)
        {
            # Explorer needs to be restarted to enact the changes.
            taskkill /F /IM explorer.exe
            Start-Process explorer.exe
        }
    }
}

[DSCResource()]
class UserAccessControl
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    hidden [string] $EnableLUA = 'EnableLUA'

    [UserAccessControl] Get()
    {
        $currentState = [UserAccessControl]::new()

        if (-not(DoesRegistryKeyPropertyExist -Path $global:UACRegistryPath -Name $this.EnableLUA))
        {
            $currentState.Ensure = [Ensure]::Present
        }
        else
        {
            $currentState.Ensure = [Ensure](Get-ItemPropertyValue -Path $global:UACRegistryPath -Name $this.EnableLUA)
        }

        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()

        if ($null -ne $this.Ensure -and $currentState.Ensure -ne $this.Ensure)
        {
            return $false
        }

        return $true
    }

    [void] Set()
    {
        if ($null -ne $this.Ensure)
        {
            Assert-IsAdministrator
            $desiredState = $this.Ensure -eq [Ensure]::Present ? 1 : 0
            Set-ItemProperty -Path $global:UACRegistryPath -Name $this.EnableLUA -Value $desiredState
        }
    }
}

[DSCResource()]
class ShowSecondsInClock
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    hidden [string] $ShowSecondsInSystemClock = 'ShowSecondsInSystemClock'

    [ShowSecondsInClock] Get()
    {
        $exists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.ShowSecondsInSystemClock
        if (-not($exists))
        {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name $this.ShowSecondsInSystemClock
        
        return @{
            Ensure = $registryValue ? [Ensure]::Present : [Ensure]::Absent
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set()
    {
        $value = ($this.Ensure -eq [Ensure]::Present) ? 1 : 0
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.ShowSecondsInSystemClock -Value $value
    }
}

[DSCResource()]
class EnableDarkMode
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty()]
    [bool] $RestartExplorer = $false

    hidden [string] $AppsUseLightTheme = 'AppsUseLightTheme'
    hidden [string] $SystemUsesLightTheme = 'SystemUsesLightTheme'

    [EnableDarkMode] Get()
    {
        $exists = (DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme) -and (DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme)
        if (-not($exists))
        {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $appsUseLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath  -Name $this.AppsUseLightTheme
        $systemUsesLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath  -Name $this.SystemUsesLightTheme

        $isDarkModeEnabled = if ($appsUseLightModeValue -eq 0 -and $systemUsesLightModeValue -eq 0) {[Ensure]::Present} else {[Ensure]::Absent}
        
        return @{
            Ensure = $isDarkModeEnabled
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set()
    {
        $value = if ($this.Ensure -eq [Ensure]::Present) {0} else {1}
        Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme -Value $value
        Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme -Value $value

        if ($this.RestartExplorer)
        {
            # Explorer needs to be restarted to enact the changes.
            Stop-Process -ProcessName Explorer
        }
    }
}
#endregion DSCResources

#region Functions
$AppModelUnlockRegistryKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\'
$DeveloperModePropertyName = 'AllowDevelopmentWithoutDevLicense'

function IsDeveloperModeEnabled
{
    try
    {
        $property = Get-ItemProperty -Path $AppModelUnlockRegistryKeyPath -Name $DeveloperModePropertyName
        return $property.AllowDevelopmentWithoutDevLicense -eq 1
    }
    catch
    {
        # This will throw an exception if the registry path or property does not exist.
        return $false;
    }
}

function SetDeveloperMode
{
    param (
        [Parameter(Mandatory)]
        [bool]$Enable
    )

    if (-not (Test-Path -Path $AppModelUnlockRegistryKeyPath))
    {
        New-Item -Path $AppModelUnlockRegistryKeyPath -Force | Out-Null
    }

    $developerModeValue = [int]$Enable
    New-ItemProperty -Path $AppModelUnlockRegistryKeyPath -Name $DeveloperModePropertyName -Value $developerModeValue -PropertyType DWORD -Force | Out-Null
}

function DoesRegistryKeyPropertyExist
{
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    # Get-ItemProperty will return $null if the registry key property does not exist.
    $itemProperty = Get-ItemProperty -Path $Path  -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $itemProperty
}

#endregion Functions