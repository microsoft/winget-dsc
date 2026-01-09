# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:ExplorerRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'
    $global:PersonalizeRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
    $global:AppModelUnlockRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\'
    $global:TimeZoneAutoUpdateRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate\'
    $global:TimeZoneInformationRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation\'
    $global:DesktopRegistryPath = 'HKCU:\Control Panel\Desktop\'
    $global:DWMRegistryPath = 'HKCU:\Software\Microsoft\Windows\DWM\'
    $global:StartRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\'
} else {
    $global:ExplorerRegistryPath = $global:PersonalizeRegistryPath = $global:AppModelUnlockRegistryPath = $global:TimeZoneAutoUpdateRegistryPath = $global:TimeZoneInformationRegistryPath = $global:DesktopRegistryPath = $global:DWMRegistryPath = $global:StartRegistryPath = $env:TestRegistryPath
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
    [Nullable[bool]] $SetTimeZoneAutomatically

    [DscProperty()]
    [string] $TimeZone

    # Personalization - Colors
    [DscProperty()]
    [Nullable[bool]] $EnableTransparency

    [DscProperty()]
    [Nullable[bool]] $ShowAccentColorOnStartAndTaskbar

    [DscProperty()]
    [Nullable[bool]] $ShowAccentColorOnTitleBarsAndWindowBorders

    [DscProperty()]
    [Nullable[bool]] $AutoColorization

    # Personalization - Start Folders
    [DscProperty()]
    [string[]] $StartFolders

    hidden [bool] $RestartExplorer = $false
    hidden [string] $TaskbarAl = 'TaskbarAl'
    hidden [string] $AppsUseLightTheme = 'AppsUseLightTheme'
    hidden [string] $SystemUsesLightTheme = 'SystemUsesLightTheme'
    hidden [string] $DeveloperModePropertyName = 'AllowDevelopmentWithoutDevLicense'
    hidden [string] $TimeZoneAutoUpdatePropertyName = 'Start'
    hidden [string] $TimeZonePropertyName = 'TimeZoneKeyName'
    hidden [string] $EnableTransparencyPropertyName = 'EnableTransparency'
    hidden [string] $ColorPrevalencePersonalizePropertyName = 'ColorPrevalence'
    hidden [string] $ColorPrevalenceDWMPropertyName = 'ColorPrevalence'
    hidden [string] $AutoColorizationPropertyName = 'AutoColorization'
    hidden [string] $VisiblePlacesPropertyName = 'VisiblePlaces'
    
    # Start folder GUIDs
    hidden [hashtable] $StartFolderGuids = @{
        'Documents'   = '{2D34D5CE-FA5A-4543-82F2-22E6EAF7773C}'
        'Downloads'   = '{E367B32F-89DE-4355-BFCE-61F37B18A937}'
        'Music'       = '{B00B0620-7F51-4C32-AA1E-34CC547F7315}'
        'Pictures'    = '{383F07A0-E80A-4C80-B05A-86DB845DBC4D}'
        'Videos'      = '{42B3A5C5-7D86-42F4-80A4-93FACA7A88B5}'
        'Network'     = '{FE758144-080D-42AE-8BDA-34ED97B66394}'
        'UserProfile' = '{74BDB04A-F94A-4F68-8BD6-4398071DA8BC}'
        'Explorer'    = '{148A24BC-D60C-4289-A080-6ED9BBA24882}'
        'Settings'    = '{52730886-51AA-4243-9F7B-2776584659D4}'
    }

    [WindowsSettings] Get() {
        $currentState = [WindowsSettings]::new()

        # Get TaskbarAlignment
        $currentState.TaskbarAlignment = $this.GetTaskbarAlignment()

        # Get ColorMode
        $currentState.AppColorMode = $this.GetAppColorMode()
        $currentState.SystemColorMode = $this.GetSystemColorMode()

        # Get DeveloperMode
        $currentState.DeveloperMode = $this.IsDeveloperModeEnabled()

        # Get TimeZone settings
        $currentState.SetTimeZoneAutomatically = $this.GetSetTimeZoneAutomatically()
        $currentState.TimeZone = $this.GetTimeZone()

        # Get Color settings
        $currentState.EnableTransparency = $this.GetEnableTransparency()
        $currentState.ShowAccentColorOnStartAndTaskbar = $this.GetShowAccentColorOnStartAndTaskbar()
        $currentState.ShowAccentColorOnTitleBarsAndWindowBorders = $this.GetShowAccentColorOnTitleBarsAndWindowBorders()
        $currentState.AutoColorization = $this.GetAutoColorization()

        # Get Start Folders
        $currentState.StartFolders = $this.GetStartFolders()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $this.TestTaskbarAlignment($currentState) -and $this.TestAppColorMode($currentState) -and $this.TestSystemColorMode($currentState) -and $this.TestDeveloperMode($currentState) -and $this.TestSetTimeZoneAutomatically($currentState) -and $this.TestTimeZone($currentState) -and $this.TestEnableTransparency($currentState) -and $this.TestShowAccentColorOnStartAndTaskbar($currentState) -and $this.TestShowAccentColorOnTitleBarsAndWindowBorders($currentState) -and $this.TestAutoColorization($currentState) -and $this.TestStartFolders($currentState)
    }

    [void] Set() {
        $currentState = $this.Get()

        # Set TaskbarAlignment
        if (!$this.TestTaskbarAlignment($currentState)) {
            $desiredAlignment = $this.TaskbarAlignment -eq 'Left' ? 0 : 1
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl -Value $desiredAlignment
        }

        # Set ColorMode
        $colorModeChanged = $false
        if (!$this.TestAppColorMode($currentState)) {
            $desiredColorMode = $this.AppColorMode -eq 'Dark' ? 0 : 1
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme -Value $desiredColorMode
            $colorModeChanged = $true
        }

        if (!$this.TestSystemColorMode($currentState)) {
            $desiredColorMode = $this.SystemColorMode -eq 'Dark' ? 0 : 1
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

        # Set TimeZone settings
        if (!$this.TestSetTimeZoneAutomatically($currentState)) {
            $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

            if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw 'Setting TimeZone automatic update requires this resource to be run as an Administrator.'
            }

            # 3 == automatic on // 4 == automatic off
            $value = $this.SetTimeZoneAutomatically ? 3 : 4
            Set-ItemProperty -Path $global:TimeZoneAutoUpdateRegistryPath -Name $this.TimeZoneAutoUpdatePropertyName -Value $value -Type DWord
        }

        if (!$this.TestTimeZone($currentState)) {
            $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

            if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw 'Setting TimeZone requires this resource to be run as an Administrator.'
            }

            # Validate timezone
            $availableTimeZones = Get-TimeZone -ListAvailable | Select-Object -ExpandProperty Id
            if ($availableTimeZones -notcontains $this.TimeZone) {
                throw "Invalid TimeZone: $($this.TimeZone). Use Get-TimeZone -ListAvailable to see valid timezone IDs."
            }

            Set-TimeZone -Id $this.TimeZone
        }

        # Set Color settings
        if (!$this.TestEnableTransparency($currentState)) {
            $value = $this.EnableTransparency ? 1 : 0
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.EnableTransparencyPropertyName -Value $value -Type DWord
        }

        if (!$this.TestShowAccentColorOnStartAndTaskbar($currentState)) {
            $value = $this.ShowAccentColorOnStartAndTaskbar ? 1 : 0
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.ColorPrevalencePersonalizePropertyName -Value $value -Type DWord
        }

        if (!$this.TestShowAccentColorOnTitleBarsAndWindowBorders($currentState)) {
            $value = $this.ShowAccentColorOnTitleBarsAndWindowBorders ? 1 : 0
            Set-ItemProperty -Path $global:DWMRegistryPath -Name $this.ColorPrevalenceDWMPropertyName -Value $value -Type DWord
        }

        if (!$this.TestAutoColorization($currentState)) {
            $value = $this.AutoColorization ? 1 : 0
            Set-ItemProperty -Path $global:DesktopRegistryPath -Name $this.AutoColorizationPropertyName -Value $value -Type DWord
        }

        # Set Start Folders
        if (!$this.TestStartFolders($currentState)) {
            $this.SetStartFolders()
        }
    }

    [string] GetTaskbarAlignment() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)) {
            return 'Center'
        }

        $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)
        return $value -eq 0 ? 'Left' : 'Center'
    }

    [string] GetAppColorMode() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme)) {
            return 'Unknown'
        }

        $appsUseLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme
        if ($appsUseLightModeValue -eq 0) {
            return 'Dark'
        }

        return 'Light'
    }

    [string] GetSystemColorMode() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme)) {
            return 'Unknown'
        }

        $systemUsesLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme
        if ($systemUsesLightModeValue -eq 0) {
            return 'Dark'
        }

        return 'Light'
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
        return $null -eq $this.DeveloperMode -or $currentState.DeveloperMode -eq $this.DeveloperMode
    }

    [bool] TestTaskbarAlignment([WindowsSettings] $currentState) {
        return $null -eq $this.TaskbarAlignment -or $currentState.TaskbarAlignment -eq $this.TaskbarAlignment
    }

    [bool] TestAppColorMode([WindowsSettings] $currentState) {
        return $null -eq $this.AppColorMode -or $currentState.AppColorMode -eq $this.AppColorMode
    }

    [bool] TestSystemColorMode([WindowsSettings] $currentState) {
        return $null -eq $this.SystemColorMode -or $currentState.SystemColorMode -eq $this.SystemColorMode
    }
    [Nullable[bool]] GetSetTimeZoneAutomatically() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:TimeZoneAutoUpdateRegistryPath -Name $this.TimeZoneAutoUpdatePropertyName)) {
            return $null
        }

        $value = Get-ItemPropertyValue -Path $global:TimeZoneAutoUpdateRegistryPath -Name $this.TimeZoneAutoUpdatePropertyName
        # 3 = automatic on, 4 = automatic off
        return $value -eq 3
    }

    [string] GetTimeZone() {
        try {
            $currentTimeZone = Get-TimeZone
            return $currentTimeZone.Id
        } catch {
            return $null
        }
    }

    [bool] TestSetTimeZoneAutomatically([WindowsSettings] $currentState) {
        return $this.SetTimeZoneAutomatically -eq $null -or $currentState.SetTimeZoneAutomatically -eq $this.SetTimeZoneAutomatically
    }

    [bool] TestTimeZone([WindowsSettings] $currentState) {
        return [string]::IsNullOrEmpty($this.TimeZone) -or $currentState.TimeZone -eq $this.TimeZone
    }

    # Color Settings Helper Methods
    [Nullable[bool]] GetEnableTransparency() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.EnableTransparencyPropertyName)) {
            return $null
        }
        $value = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.EnableTransparencyPropertyName
        return $value -eq 1
    }

    [bool] TestEnableTransparency([WindowsSettings] $currentState) {
        return $this.EnableTransparency -eq $null -or $currentState.EnableTransparency -eq $this.EnableTransparency
    }

    [Nullable[bool]] GetShowAccentColorOnStartAndTaskbar() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.ColorPrevalencePersonalizePropertyName)) {
            return $null
        }
        $value = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.ColorPrevalencePersonalizePropertyName
        return $value -eq 1
    }

    [bool] TestShowAccentColorOnStartAndTaskbar([WindowsSettings] $currentState) {
        return $this.ShowAccentColorOnStartAndTaskbar -eq $null -or $currentState.ShowAccentColorOnStartAndTaskbar -eq $this.ShowAccentColorOnStartAndTaskbar
    }

    [Nullable[bool]] GetShowAccentColorOnTitleBarsAndWindowBorders() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DWMRegistryPath -Name $this.ColorPrevalenceDWMPropertyName)) {
            return $null
        }
        $value = Get-ItemPropertyValue -Path $global:DWMRegistryPath -Name $this.ColorPrevalenceDWMPropertyName
        return $value -eq 1
    }

    [bool] TestShowAccentColorOnTitleBarsAndWindowBorders([WindowsSettings] $currentState) {
        return $this.ShowAccentColorOnTitleBarsAndWindowBorders -eq $null -or $currentState.ShowAccentColorOnTitleBarsAndWindowBorders -eq $this.ShowAccentColorOnTitleBarsAndWindowBorders
    }

    [Nullable[bool]] GetAutoColorization() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DesktopRegistryPath -Name $this.AutoColorizationPropertyName)) {
            return $null
        }
        $value = Get-ItemPropertyValue -Path $global:DesktopRegistryPath -Name $this.AutoColorizationPropertyName
        return $value -eq 1
    }

    [bool] TestAutoColorization([WindowsSettings] $currentState) {
        return $this.AutoColorization -eq $null -or $currentState.AutoColorization -eq $this.AutoColorization
    }

    # Start Folders Helper Methods
    [string[]] GetStartFolders() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:StartRegistryPath -Name $this.VisiblePlacesPropertyName)) {
            return @()
        }

        try {
            $binaryData = Get-ItemPropertyValue -Path $global:StartRegistryPath -Name $this.VisiblePlacesPropertyName
            $folders = @()
            
            # Parse binary data to extract GUIDs
            $guidPattern = '([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})'
            $guidMatches = [regex]::Matches([System.Text.Encoding]::Unicode.GetString($binaryData), $guidPattern)
            
            foreach ($match in $guidMatches) {
                $guid = '{' + $match.Value.ToUpper() + '}'
                # Find folder name from GUID
                foreach ($folderName in $this.StartFolderGuids.Keys) {
                    if ($this.StartFolderGuids[$folderName] -eq $guid) {
                        $folders += $folderName
                        break
                    }
                }
            }
            
            return $folders
        } catch {
            return @()
        }
    }

    [void] SetStartFolders() {
        if ($null -eq $this.StartFolders -or $this.StartFolders.Count -eq 0) {
            # Remove the registry value if no folders specified
            if (DoesRegistryKeyPropertyExist -Path $global:StartRegistryPath -Name $this.VisiblePlacesPropertyName) {
                Remove-ItemProperty -Path $global:StartRegistryPath -Name $this.VisiblePlacesPropertyName -ErrorAction SilentlyContinue
            }
            return
        }

        # Validate folder names
        foreach ($folder in $this.StartFolders) {
            if (-not $this.StartFolderGuids.ContainsKey($folder)) {
                throw "Invalid Start folder name: $folder. Valid values are: $($this.StartFolderGuids.Keys -join ', ')"
            }
        }

        # Build binary data from GUIDs
        $guidStrings = @()
        foreach ($folder in $this.StartFolders) {
            $guidStrings += $this.StartFolderGuids[$folder]
        }

        # Create binary data (simplified version - actual format is more complex)
        # Each GUID needs to be encoded as Unicode bytes
        $binaryData = New-Object System.Collections.ArrayList
        foreach ($guid in $guidStrings) {
            $guidBytes = [System.Text.Encoding]::Unicode.GetBytes($guid)
            [void]$binaryData.AddRange($guidBytes)
        }

        # Ensure registry path exists
        if (-not (Test-Path $global:StartRegistryPath)) {
            New-Item -Path $global:StartRegistryPath -Force | Out-Null
        }

        Set-ItemProperty -Path $global:StartRegistryPath -Name $this.VisiblePlacesPropertyName -Value ([byte[]]$binaryData.ToArray()) -Type Binary
    }

    [bool] TestStartFolders([WindowsSettings] $currentState) {
        if ($null -eq $this.StartFolders) {
            return $true
        }

        $current = $currentState.StartFolders
        $desired = $this.StartFolders

        if ($current.Count -ne $desired.Count) {
            return $false
        }

        # Compare sorted arrays
        $currentSorted = $current | Sort-Object
        $desiredSorted = $desired | Sort-Object

        for ($i = 0; $i -lt $currentSorted.Count; $i++) {
            if ($currentSorted[$i] -ne $desiredSorted[$i]) {
                return $false
            }
        }

        return $true
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

    Add-Type @'
using System;
using System.Runtime.InteropServices;

public class NativeMethods {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
'@

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
        'ImmersiveColorSet',
        $SMTO_ABORTIFHUNG,
        $timeout,
        [ref]$result
    )
}
