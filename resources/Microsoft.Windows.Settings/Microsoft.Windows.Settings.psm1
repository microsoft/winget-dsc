# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:ExplorerRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'
    $global:PersonalizeRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
    $global:AppModelUnlockRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\'
    $global:LongPathsRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem\'
} else {
    $global:ExplorerRegistryPath = $global:PersonalizeRegistryPath = $global:AppModelUnlockRegistryPath = $global:LongPathsRegistryPath = $env:TestRegistryPath
}

[DSCResource()]
class WindowsSettings {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string] $SID

    [DscProperty()]
    [string] $TaskbarAlignment

    [DscProperty()]
    [string] $AppColorMode

    [DscProperty()]
    [string] $SystemColorMode

    [DscProperty()]
    [Nullable[bool]] $DeveloperMode

    [DscProperty()]
    [System.Version] $OsVersion

    [DscProperty()]
    [Nullable[bool]] $HideFileExtensions

    [DscProperty()]
    [Nullable[bool]] $ShowHiddenFiles

    [DscProperty()]
    [Nullable[bool]] $LongPathsEnabled

    hidden [bool] $RestartExplorer = $false

    # Registry keys
    hidden [string] $TaskbarAlignmentRegKey = 'TaskbarAl'
    hidden [string] $AppsUseLightThemeRegKey = 'AppsUseLightTheme'
    hidden [string] $SystemUsesLightThemeRegKey = 'SystemUsesLightTheme'
    hidden [string] $DeveloperModeRegKey = 'AllowDevelopmentWithoutDevLicense'
    hidden [string] $HideFileExtRegKey = 'HideFileExt'
    hidden [string] $HiddenRegKey = 'Hidden'
    hidden [string] $LongPathsEnabledRegKey = 'LongPathsEnabled'

    # Property values
    hidden [string] $LeftValue = 'Left'
    hidden [string] $CenterValue = 'Center'
    hidden [string] $DarkValue = 'Dark'
    hidden [string] $LightValue = 'Light'
    hidden [string] $UnknownValue = 'Unknown'

    [WindowsSettings] Get() {
        $currentState = [WindowsSettings]::new()

        # Get TaskbarAlignment
        $currentState.TaskbarAlignment = $this.GetTaskbarAlignment()

        # Get ColorMode
        $currentState.AppColorMode = $this.GetAppColorMode()
        $currentState.SystemColorMode = $this.GetSystemColorMode()

        # Get DeveloperMode
        $currentState.DeveloperMode = $this.IsDeveloperModeEnabled()

        # Get OS Version
        $currentState.OsVersion = $this.GetOsVersion()

        # Get File Extensions visibility
        $currentState.HideFileExtensions = $this.IsFileExtensionsHidden()

        # Get Hidden Files visibility
        $currentState.ShowHiddenFiles = $this.AreHiddenFilesShown()

        # Get Long Paths Enabled
        $currentState.LongPathsEnabled = $this.IsLongPathsEnabled()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        return (
            $this.TestTaskbarAlignment($currentState) -and
            $this.TestAppColorMode($currentState) -and
            $this.TestSystemColorMode($currentState) -and
            $this.TestDeveloperMode($currentState) -and
            $this.TestOsVersion($currentState) -and
            $this.TestHideFileExtensions($currentState) -and
            $this.TestHiddenFilesShown($currentState) -and
            $this.TestLongPathsEnabled($currentState)
        )
    }

    [void] Set() {
        $currentState = $this.Get()

        # Set TaskbarAlignment
        if (!$this.TestTaskbarAlignment($currentState)) {
            ValidateInput -ParamName "TaskbarAlignment" -InputValue $this.TaskbarAlignment -ValidValues @($this.LeftValue, $this.CenterValue)

            $desiredAlignment = $this.TaskbarAlignment -eq $this.LeftValue ? 0 : 1
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAlignmentRegKey -Value $desiredAlignment
        }

        # Set ColorMode
        $colorModeChanged = $false
        if (!$this.TestAppColorMode($currentState)) {
            ValidateInput -ParamName "AppColorMode" -InputValue $this.AppColorMode -ValidValues @($this.DarkValue, $this.LightValue)

            $desiredColorMode = $this.AppColorMode -eq $this.DarkValue ? 0 : 1
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightThemeRegKey -Value $desiredColorMode
            $colorModeChanged = $true
        }

        if (!$this.TestSystemColorMode($currentState)) {
            ValidateInput -ParamName "SystemColorMode" -InputValue $this.SystemColorMode -ValidValues @($this.DarkValue, $this.LightValue)

            $desiredColorMode = $this.SystemColorMode -eq $this.DarkValue ? 0 : 1
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightThemeRegKey -Value $desiredColorMode
            $colorModeChanged = $true
        }

        # Notify Explorer of theme change
        if ($colorModeChanged) {
            SendImmersiveColorSetMessage
        }

        # Restart Explorer if needed
        if ($this.RestartExplorer) {
            taskkill /F /IM explorer.exe
            Start-Process explorer.exe
        }

        # Set DeveloperMode
        if (!$this.TestDeveloperMode($currentState)) {
            AdministratorRequired -Name "DeveloperMode"
            $value = $this.DeveloperMode ? 1 : 0
            Set-ItemProperty -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModeRegKey -Value $value
        }

        # Set HideFileExt
        if (!$this.TestHideFileExtensions($currentState)) {
            $value = $this.HideFileExtensions ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HideFileExtRegKey -Value $value
            SendShellStateMessage
        }

        # Set ShowHiddenFiles
        if (!$this.TestHiddenFilesShown($currentState)) {
            $value = $this.ShowHiddenFiles ? 1 : 0
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.HiddenRegKey -Value $value
            SendShellStateMessage
        }

        # Set LongPathsEnabled
        if (!$this.TestLongPathsEnabled($currentState)) {
            AdministratorRequired -Name "LongPathsEnabled"
            $value = $this.LongPathsEnabled ? 1 : 0
            Set-ItemProperty -Path $global:LongPathsRegistryPath -Name $this.LongPathsEnabledRegKey -Value $value
        }
    }

    [string] GetTaskbarAlignment() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAlignmentRegKey)) {
            return $this.CenterValue
        }

        $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarAlignmentRegKey)
        return $value -eq 0 ? $this.LeftValue : $this.CenterValue
    }

    [string] GetAppColorMode() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightThemeRegKey)) {
            return $this.UnknownValue
        }

        $appsUseLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightThemeRegKey
        if ($appsUseLightModeValue -eq 0) {
            return $this.DarkValue
        }

        return $this.LightValue
    }

    [string] GetSystemColorMode() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightThemeRegKey)) {
            return $this.UnknownValue
        }

        $systemUsesLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightThemeRegKey
        if ($systemUsesLightModeValue -eq 0) {
            return $this.DarkValue
        }

        return $this.LightValue
    }

    [bool] IsDeveloperModeEnabled() {
        $regExists = DoesRegistryKeyPropertyExist -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModeRegKey

        # If the registry key does not exist, we assume developer mode is not enabled.
        if (-not($regExists)) {
            return $false
        }

        return Get-ItemPropertyValue -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModeRegKey
    }

    [System.Version] GetOsVersion() {
        return (Get-ComputerInfo | Select-Object OsVersion).OsVersion
    }

    [bool] IsFileExtensionsHidden() {
        $regExists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.HideFileExtRegKey
        if (-not($regExists)) {
            return $false
        }

        return Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.HideFileExtRegKey
    }

    [bool] AreHiddenFilesShown() {
        $regExists = DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.HiddenRegKey
        if (-not($regExists)) {
            return $true
        }

        return Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.HiddenRegKey
    }

    [bool] IsLongPathsEnabled() {
        $regExists = DoesRegistryKeyPropertyExist -Path $global:LongPathsRegistryPath -Name $this.LongPathsEnabledRegKey
        if (-not($regExists)) {
            return $false
        }

        return Get-ItemPropertyValue -Path $global:LongPathsRegistryPath -Name $this.LongPathsEnabledRegKey
    }

    [bool] TestDeveloperMode([WindowsSettings] $currentState) {
        return $this.DeveloperMode -eq $null -or $currentState.DeveloperMode -eq $this.DeveloperMode
    }

    [bool] TestTaskbarAlignment([WindowsSettings] $currentState) {
        return $this.TaskbarAlignment -eq $null -or $currentState.TaskbarAlignment -eq $this.TaskbarAlignment
    }

    [bool] TestAppColorMode([WindowsSettings] $currentState) {
        return $this.AppColorMode -eq $null -or $currentState.AppColorMode -eq $this.AppColorMode
    }

    [bool] TestSystemColorMode([WindowsSettings] $currentState) {
        return $this.SystemColorMode -eq $null -or $currentState.SystemColorMode -eq $this.SystemColorMode
    }

    [bool] TestOsVersion([WindowsSettings] $currentState) {
        return $this.OsVersion -eq $null -or $currentState.OsVersion -eq $this.OsVersion
    }

    [bool] TestHideFileExtensions([WindowsSettings] $currentState) {
        return $this.HideFileExtensions -eq $null -or $currentState.HideFileExtensions -eq $this.HideFileExtensions
    }

    [bool] TestHiddenFilesShown([WindowsSettings] $currentState) {
        return $this.ShowHiddenFiles -eq $null -or $currentState.ShowHiddenFiles -eq $this.ShowHiddenFiles
    }

    [bool] TestLongPathsEnabled([WindowsSettings] $currentState) {
        return $this.LongPathsEnabled -eq $null -or $currentState.LongPathsEnabled -eq $this.LongPathsEnabled
    }
}

function AdministratorRequired {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

    if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This operation on $Name requires Administrator privileges."
    }
}

function ValidateInput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ParamName,

        [Parameter(Mandatory = $true)]
        [string]$InputValue,

        [Parameter(Mandatory = $true)]
        [string[]]$ValidValues
    )

    if (-not ($ValidValues -contains $InputValue)) {
        throw "Invalid value for $ParamName. Valid values are: $($ValidValues -join ', ')."
    }
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

function SendImmersiveColorSetMessage {
    SendMessageTimeout -Message "ImmersiveColorSet"
}

function SendShellStateMessage {
    SendMessageTimeout -Message "ShellState"
}

function SendMessageTimeout {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class NativeMethods {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@

    # Constants
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    $SMTO_ABORTIFHUNG = 0x0002
    $timeout = 100
    $result = [UIntPtr]::Zero

    # Notify Explorer of theme change
    [void][NativeMethods]::SendMessageTimeout(
        $HWND_BROADCAST,
        $WM_SETTINGCHANGE,
        [UIntPtr]::Zero,
        $Message,
        $SMTO_ABORTIFHUNG,
        $timeout,
        [ref]$result
    )
}
