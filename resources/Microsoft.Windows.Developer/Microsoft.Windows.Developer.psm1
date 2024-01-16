# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

enum Ensure
{
    Absent
    Present
}

enum Alignment
{
    Left = 0
    Middle = 1
}

enum HideTaskBarLabelsBehavior
{
    Always = 0
    WhenFull = 1
    Never = 2
}

enum ShowHideFeature
{
    Show = 0
    Hide = 1
}

enum TaskbarSearchBoxMode {
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
    [DscProperty()] [Alignment] $Alignment
    [DscProperty()] [HideTaskBarLabelsBehavior] $HideLabelsMode
    [DscProperty()] [TaskbarSearchboxMode] $SearchboxMode
    [DscProperty()] [ShowHideFeature] $TaskViewButton
    [DscProperty()] [ShowHideFeature] $WidgetsButton

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
        else {
            $currentState.Alignment = [Alignment](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)
        }

        # HideTaskBarLabels
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel))
        {
            $currentState.HideLabelsMode = [HideTaskBarLabelsBehavior]::Always
        }
        else {
            $currentState.HideLabelsMode = [HideTaskBarLabelsBehavior](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel)
        }

        # TaskbarSearchboxMode
        if (-not(DoesRegistryKeyPropertyExist -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode))
        {
            $currentState.SearchboxMode = [TaskbarSearchBoxMode]::SearchBox
        }
        else
        {
            $currentState.SearchboxMode = [TaskbarSearchBoxMode](Get-ItemPropertyValue -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode)
        }

        # TaskViewButton
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton))
        {
            $currentState.TaskViewButton = [ShowHideFeature]::Show
        }
        else
        {
            $currentState.TaskViewButton = [ShowHideFeature](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton)
        }

        # WidgetsButton
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarDa))
        {
            $currentState.WidgetsButton = [ShowHideFeature]::Show
        }
        else {
            $currentState.WidgetsButton = [ShowHideFeature](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarDa)
        }

        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        
        if ($null -ne $this.Alignment -and $currentState.Alignment -ne $this.Alignment)
        {
            return $false
        }

        if ($null -ne $this.HideLabelsMode -and $currentState.HideLabelsMode -ne $this.HideLabelsMode)
        {
            return $false
        }

        if ($null -ne $this.SearchboxMode -and $currentState.SearchboxMode -ne $this.SearchboxMode)
        {
            return $false
        }

        if ($null -ne $this.TaskViewButton -and $currentState.TaskViewButton -ne $this.TaskViewButton)
        {
            return $false
        }

        if ($null -ne $this.WidgetsButton -and $currentState.WidgetsButton -ne $this.WidgetsButton)
        {
            return $false
        }

        return $true
    }

    [void] Set()
    {
        if ($null -ne $this.Alignment)
        {
            $desiredAlignment = [int]$this.Alignment
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl -Value $desiredAlignment
        }

        if ($null -ne $this.HideLabelsMode)
        {
            $desiredHideLabelsBehavior = [int]$this.HideLabelsMode
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel -Value $desiredHideLabelsBehavior
        }

        if ($null -ne $this.SearchboxMode)
        {
            $desiredSearchboxMode = [int]$this.SearchboxMode
            Set-ItemProperty -Path $global:SearchRegistryPath -Name $this.SearchboxTaskbarMode -Value $desiredSearchboxMode
        }

        if ($null -ne $this.TaskViewButton)
        {
            $desiredTaskViewButtonMode = [int]$this.ShowTaskViewButton
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton -Value $desiredTaskViewButtonMode
        }

        if ($null -ne $this.WidgetsButton)
        {
            $desiredWidgetsButtonMode = [int]$this.WidgetsButton
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskBarDa -Value $desiredWidgetsButtonMode
        }

        if ($this.RestartExplorer)
        {
            # Explorer needs to be restarted to enact the changes.
            Stop-Process -ProcessName Explorer
        }
    }
}

[DSCResource()]
class WindowsExplorer
{
    [DscProperty()] [ShowHideFeature] $FileExtensions
    [DscProperty()] [ShowHideFeature] $HiddenFiles
    [DscProperty()] [ShowHideFeature] $ItemCheckBoxes

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
            $currentState.FileExtensions = [ShowHideFeature](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.HideFileExt)
        }

        # HiddenFiles
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.Hidden))
        {
            $currentState.HiddenFiles = [ShowHideFeature]::Show
        }
        else
        {
            $currentState.HiddenFiles = [ShowHideFeature](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.Hidden)
        }

        # ItemCheckboxes
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.AutoCheckSelect))
        {
            $currentState.ItemCheckBoxes = [ShowHideFeature]::Show
        }
        else
        {
            $currentState.ItemCheckBoxes = [ShowHideFeature](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.AutoCheckSelect)
        }


        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        
        if ($null -ne $this.FileExtensions -and $currentState.FileExtensions -ne $this.FileExtensions)
        {
            return $false
        }

        if ($null -ne $this.HiddenFiles -and $currentState.HiddenFiles -ne $this.HiddenFiles)
        {
            return $false
        }

        if ($null -ne $this.ItemCheckBoxes -and $currentState.ItemCheckBoxes -ne $this.ItemCheckBoxes)
        {
            return $false
        }

        return $true
    }

    [void] Set()
    {
        if ($null -ne $this.FileExtensions)
        {
            $desiredFileExtensions = [int]$this.FileExtensions
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HideFileExt -Value $desiredFileExtensions
        }

        if ($null -ne $this.HiddenFiles)
        {
            $desiredHiddenFiles = [int]$this.HiddenFiles
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HiddenFiles -Value $desiredHiddenFiles
        }

        if ($null -ne $this.ItemCheckBoxes)
        {
            $desiredItemCheckBoxes = [int]$this.ItemCheckBoxes
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HideFileExt -Value $desiredItemCheckBoxes
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
    [Ensure] $Ensure

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

        return currentState
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
            $desiredState = [int]$this.Ensure
            Set-ItemProperty -Path $global:UACRegistryPath -Name $this.Ensure -Value $desiredState
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