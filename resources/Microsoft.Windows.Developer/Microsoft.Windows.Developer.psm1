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

#region DSCResources
[DSCResource()]
class DeveloperMode
{
    [DscProperty(Key)]
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
    [DscProperty(Key)]
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

[DSCResource()]
class TaskBarAlignment
{
    [DscProperty(Key)]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty()]
    [Alignment] $Alignment

    [TaskBarAlignment] Get()
    {
        $alignmentValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name 'TaskbarAl'
        return @{
            Ensure = [Ensure]::Present
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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name 'TaskbarAl' -Value $desiredAlignment
    }
}

[DSCResource()]
class ShowSecondsInClock
{
    [DscProperty(Key)]
    [Ensure] $Ensure = [Ensure]::Present

    [ShowSecondsInClock] Get()
    {
        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name 'ShowSecondsInSystemClock'
        
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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name 'ShowSecondsInSystemClock' -Value $value
    }
}

[DSCResource()]
class HideFileExtensions
{
    [DscProperty(Key)]
    [Ensure] $Ensure = [Ensure]::Present

    [HideFileExtensions] Get()
    {
        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name 'HideFileExt'
        
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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name 'HideFileExt' -Value $value
    }
}

[DSCResource()]
class ShowTaskViewButton
{
    [DscProperty(Key)]
    [Ensure] $Ensure = [Ensure]::Present

    [ShowTaskViewButton] Get()
    {
        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name 'ShowTaskViewButton'

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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name 'ShowTaskViewButton' -Value $value
    }
}

[DSCResource()]
class ShowHiddenFiles
{
    [DscProperty(Key)]
    [Ensure] $Ensure = [Ensure]::Present

    [ShowHiddenFiles] Get()
    {
        $registryValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name 'Hidden'
        
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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name 'Hidden' -Value $value
    }
}

[DSCResource()]
class HideTaskBarLabels
{
    [DscProperty(Key)]
    [HideTaskBarLabelsBehavior] $HideLabels

    [DscProperty()]
    [bool] $RestartExplorer = $false

    [HideTaskBarLabels] Get()
    {
        $hideLabelsValue = Get-ItemPropertyValue -Path $global:ExplorerRegistryPath  -Name 'TaskbarGlomLevel'

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
        Set-ItemProperty -Path $global:ExplorerRegistryPath -Name 'TaskbarGlomLevel' -Value $desiredHideLabelsBehavior

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
    [DscProperty(Key)]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty()]
    [bool] $RestartExplorer = $false

    [EnableDarkMode] Get()
    {
        $appsUseLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath  -Name 'AppsUseLightTheme'
        $systemUsesLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath  -Name 'SystemUsesLightTheme'

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
        Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name 'AppsUseLightTheme' -Value $value
        Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name 'SystemUsesLightTheme' -Value $value

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

#endregion Functions