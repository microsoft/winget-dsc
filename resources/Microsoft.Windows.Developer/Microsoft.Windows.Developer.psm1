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
    KeepCurrentValue
}

enum HideTaskBarLabelsBehavior
{
    Always = 0
    WhenFull = 1
    Never = 2
    KeepCurrentValue
}

enum ShowHideFeature
{
    Show = 0
    Hide = 1
    KeepCurrentValue
}

enum TaskbarSearchBoxMode {
    Hidden = 0
    ShowIconOnly = 1
    ShowIconAndLabel = 2
    KeepCurrentValue
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

# Is Keep Current value even needed? It makes the enum value weird.
[DSCResource()]
class Taskbar
{
    [DscProperty()] [Alignment] $Alignment
    [DscProperty()] [HideTaskBarLabelsBehavior] $HideLabelsMode
    [DscProperty()] [TaskbarSearchboxMode] $SearchboxMode
    [DscProperty()] [ShowHideFeature] $TaskViewButton
    [DscProperty()] [ShowHideFeature] $WidgetsButton

    [DscProperty(Key)] [string]$SID

    hidden [string] $TaskbarAl = 'TaskbarAl'
    hidden [string] $TaskbarGlomLevel = 'TaskbarGlomLevel'

    [Taskbar] Get()
    {
        $currentState = [Taskbar]::new()

        # Alignment
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl))
        {
            $currentState.Alignment = [Alignment]::Middle
        }
        else {
            $currentState.Alignment = [Alignment](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name $this.TaskbarAl)
        }

        # HideTaskBarLabels
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel))
        {
            $currentState.HideLabelsMode = [HideTaskBarLabelsBehavior]::Always
        }
        else {
            $currentState.HideLabelsMode = [HideTaskBarLabelsBehavior](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name $this.TaskbarGlomLevel)
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

        # if ($this.RestartExplorer)
        # {
        #     # Explorer needs to be restarted to enact the changes.
        #     Stop-Process -ProcessName Explorer
        # }
    }
}

# [DSCResource()]
# class WindowsExplorer
# {
#     [DscProperty()] [ShowHideFeature] $FileExtensions
#     [DscProperty()] [ShowHideFeature] $HiddenFiles
#     [DscProperty()] [ShowHideFeature] $ItemCheckBoxes

#     [DscProperty(Key)] [string]$SID

#     [WindowsExplorer] Get()
#     {
#         return @{}
#     }

#     [bool] Test()
#     {
#         return $true
#     }

#     [void] Set()
#     {
#     }
# }

[DSCResource()]
class TaskBarAlignment
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Alignment] $Alignment

    hidden [string] $TaskbarAl = 'TaskbarAl'

    [TaskBarAlignment] Get()
    {
        $exists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl
        if (-not($exists))
        {
            return @{
                Alignment = [Alignment]::Middle
            }
        }

        $alignmentValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name $this.TaskbarAl
        return @{
            Alignment = [Alignment]$alignmentValue
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.Alignment -eq $this.Alignment
    }

    [void] Set()
    {
        $desiredAlignment = [int]$this.Alignment
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl -Value $desiredAlignment
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
class HideFileExtensions
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID    

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    hidden [string] $HideFileExt = 'HideFileExt'

    [HideFileExtensions] Get()
    {
        $exists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.HideFileExt
        if (-not($exists))
        {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name $this.HideFileExt
        
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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HideFileExt -Value $value
    }
}

[DSCResource()]
class ShowTaskViewButton
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    hidden [string] $ShowTaskViewButton = 'ShowTaskViewButton'

    [ShowTaskViewButton] Get()
    {
        $exists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton
        if (-not($exists))
        {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name $this.ShowTaskViewButton

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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.ShowTaskViewButton -Value $value
    }
}

[DSCResource()]
class ShowHiddenFiles
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    hidden [string] $Hidden = 'Hidden'

    [ShowHiddenFiles] Get()
    {
        $exists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.Hidden
        if (-not($exists))
        {
            return @{
                Ensure = [Ensure]::Absent
            }
        }

        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name $this.Hidden
        
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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.Hidden -Value $value
    }
}

[DSCResource()]
class HideTaskBarLabels
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty(Mandatory)]
    [HideTaskBarLabelsBehavior] $HideLabels

    [DscProperty()]
    [bool] $RestartExplorer = $false

    hidden [string] $TaskbarGlomLevel = 'TaskbarGlomLevel'

    [HideTaskBarLabels] Get()
    {
        $exists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel
        if (-not($exists))
        {
            return @{
                HideLabels = [HideTaskBarLabelsBehavior]::Always
            }
        }

        $hideLabelsValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name $this.TaskbarGlomLevel

        return @{
            HideLabels = [HideTaskBarLabelsBehavior]$hideLabelsValue
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.HideLabels -eq $this.HideLabels
    }

    [void] Set()
    {
        $desiredHideLabelsBehavior = [int]$this.HideLabels
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarGlomLevel -Value $desiredHideLabelsBehavior

        if ($this.RestartExplorer)
        {
            # Explorer needs to be restarted to enact the changes.
            Stop-Process -ProcessName Explorer
        }
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