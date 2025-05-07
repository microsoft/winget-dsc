# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:ExplorerRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'
    $global:PersonalizeRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
} else {
    $global:ExplorerRegistryPath = $global:PersonalizeRegistryPath = $env:TestRegistryPath
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

    hidden [bool] $RestartExplorer = $false
    hidden [string] $TaskbarAl = 'TaskbarAl'
    hidden [string] $AppsUseLightTheme = 'AppsUseLightTheme'
    hidden [string] $SystemUsesLightTheme = 'SystemUsesLightTheme'

    [WindowsSettings] Get() {
        $currentState = [WindowsSettings]::new()

        # Get TaskbarAlignment
        $currentState.TaskbarAlignment = $this.GetTaskbarAlignment()

        # Get ColorMode
        $currentState.AppColorMode = $this.GetAppColorMode()
        $currentState.SystemColorMode = $this.GetSystemColorMode()

        # Set to false on Get
        $currentState.RestartExplorer = $false

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        
        # Test TaskbarAlignment
        if ($this.TaskbarAlignment -ne $null -and $currentState.TaskbarAlignment -ne $this.TaskbarAlignment) {
            return $false
        }

        # Test ColorMode
        if ($this.AppColorMode -ne $null -and $currentState.AppColorMode -ne $this.AppColorMode) {
            return $false
        }

        if ($this.SystemColorMode -ne $null -and $currentState.SystemColorMode -ne $this.SystemColorMode) {
            return $false
        }

        return $true
    }

    [void] Set() {
        # Set TaskbarAlignment
        if ($this.TaskbarAlignment -ne $null) {
            $desiredAlignment = $this.TaskbarAlignment -eq "Left" ? 0 : 1
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl -Value $desiredAlignment
        }

        # Set ColorMode
        $colorModeChanged = $false
        if ($this.AppColorMode -eq "Dark") {
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme -Value 0
            $colorModeChanged = $true
        } elseif ($this.AppColorMode -eq "Light") {
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme -Value 1
            $colorModeChanged = $true
        }

        if ($this.SystemColorMode -eq "Dark") {
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme -Value 0
            $colorModeChanged = $true
        } elseif ($this.SystemColorMode -eq "Light") {
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme -Value 1
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
    }

    [string] GetTaskbarAlignment() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)) {
            return "Middle"
        }

        $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)
        return $value -eq 0 ? "Left" : "Middle"
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