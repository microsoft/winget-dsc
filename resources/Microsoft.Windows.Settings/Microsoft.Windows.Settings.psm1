# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:ExplorerRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'
    $global:PersonalizeRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
    $global:AppModelUnlockRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\'
} else {
    $global:ExplorerRegistryPath = $global:PersonalizeRegistryPath = $global:AppModelUnlockRegistryPath = $env:TestRegistryPath
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

    hidden [bool] $RestartExplorer = $false
    hidden [string] $TaskbarAl = 'TaskbarAl'
    hidden [string] $AppsUseLightTheme = 'AppsUseLightTheme'
    hidden [string] $SystemUsesLightTheme = 'SystemUsesLightTheme'
    hidden [string] $DeveloperModePropertyName = 'AllowDevelopmentWithoutDevLicense'

    [WindowsSettings] Get() {
        $currentState = [WindowsSettings]::new()

        # Get TaskbarAlignment
        $currentState.TaskbarAlignment = $this.GetTaskbarAlignment()

        # Get ColorMode
        $currentState.AppColorMode = $this.GetAppColorMode()
        $currentState.SystemColorMode = $this.GetSystemColorMode()

        # Get DeveloperMode
        $currentState.DeveloperMode = $this.IsDeveloperModeEnabled()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $this.TestTaskbarAlignment($currentState) -and $this.TestAppColorMode($currentState) -and $this.TestSystemColorMode($currentState) -and $this.TestDeveloperMode($currentState)
    }

    [void] Set() {
        $currentState = $this.Get()

        # Set TaskbarAlignment
        if (!$this.TestTaskbarAlignment($currentState)) {
            $desiredAlignment = $this.TaskbarAlignment -eq "Left" ? 0 : 1
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl -Value $desiredAlignment
        }

        # Set ColorMode
        $colorModeChanged = $false
        if (!$this.TestAppColorMode($currentState)) {
            $desiredColorMode = $this.AppColorMode -eq "Dark" ? 0 : 1
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme -Value $desiredColorMode
            $colorModeChanged = $true
        }

        if (!$this.TestSystemColorMode($currentState)) {
            $desiredColorMode = $this.SystemColorMode -eq "Dark" ? 0 : 1
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme -Value $desiredColorMode
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
            $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

            if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw 'Toggling Developer Mode requires this resource to be run as an Administrator.'
            }

            # 1 == enabled // 0 == disabled
            $value = $this.DeveloperMode ? 1 : 0
            Set-ItemProperty -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModePropertyName -Value $value
        }
    }

    [string] GetTaskbarAlignment() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)) {
            return "Center"
        }

        $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)
        return $value -eq 0 ? "Left" : "Center"
    }

    [string] GetAppColorMode() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme)) {
            return "Unknown"
        }

        $appsUseLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme
        if ($appsUseLightModeValue -eq 0) {
            return "Dark"
        }

        return "Light"
    }

    [string] GetSystemColorMode() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme)) {
            return "Unknown"
        }

        $systemUsesLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme
        if ($systemUsesLightModeValue -eq 0) {
            return "Dark"
        }

        return "Light"
    }

    [bool] IsDeveloperModeEnabled() {
        $regExists = DoesRegistryKeyPropertyExist -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModePropertyName

        # If the registry key does not exist, we assume developer mode is not enabled.
        if (-not($regExists)) {
            return $false
        }

        return Get-ItemPropertyValue -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModePropertyName
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
    param()

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
        "ImmersiveColorSet",
        $SMTO_ABORTIFHUNG,
        $timeout,
        [ref]$result
    )
}
