# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:USBShellPath = 'HKCU:\Software\Microsoft\Shell\USB\'
    $global:USBMachinePath = 'HKLM:\SYSTEM\CurrentControlSet\Control\USB\AutomaticSurpriseRemoval\'
    $global:TabletTipPath = 'HKCU:\Software\Microsoft\TabletTip\EmbeddedInkControl\'
    $global:MousePath = 'HKCU:\Control Panel\Mouse\'
    $global:DesktopPath = 'HKCU:\Control Panel\Desktop\'
} else {
    $global:USBShellPath = $env:TestRegistryPath
}

#region Enums
enum FingerTipFont {
    InkFree
    SegoeUI
}

enum PrimaryButton {
    Left
    Right
}

enum ScrollDirection {
    Down
    Up
}
#endregion Enums

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

function Test-Assembly {
    param (
        [Parameter(Mandatory)]
        [string] $AssemblyName
    )

    $assembly = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $AssemblyName }
    return $null -ne $assembly
}

function Import-Type {
    param (
        [Parameter(Mandatory)]
        [string] $AssemblyName
    )

    switch ($AssemblyName) {
        'Touchpad32Functions' {
            Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public enum LEGACY_TOUCHPAD_FEATURES
{
    LEGACY_TOUCHPAD_FEATURE_NONE = 0x00000000,
    LEGACY_TOUCHPAD_FEATURE_ENABLE_DISABLE = 0x00000001,
    LEGACY_TOUCHPAD_FEATURE_REVERSE_SCROLL_DIRECTION = 0x00000004
}

public enum TOUCHPAD_SENSITIVITY_LEVEL
{
    TOUCHPAD_SENSITIVITY_LEVEL_MOST_SENSITIVE = 0x00000000,
    TOUCHPAD_SENSITIVITY_LEVEL_HIGH_SENSITIVITY = 0x00000001,
    TOUCHPAD_SENSITIVITY_LEVEL_MEDIUM_SENSITIVITY = 0x00000002,
    TOUCHPAD_SENSITIVITY_LEVEL_LOW_SENSITIVITY = 0x00000003,
    TOUCHPAD_SENSITIVITY_LEVEL_LEAST_SENSITIVE = 0x00000004
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct TOUCHPAD
{
    public uint versionNumber;
    public uint maxSupportedContacts;
    public LEGACY_TOUCHPAD_FEATURES legacyTouchpadFeatures;
    public bool touchpadPresent;
    public bool legacyTouchpadPresent;
    public bool externalMousePresent;
    public bool touchpadEnabled;
    public bool touchpadActive;
    public bool feedbackSupported;
    public bool clickForceSupported;
    public bool Reserved1;
    public bool allowActiveWhenMousePresent;
    public bool feedbackEnabled;
    public bool tapEnabled;
    public bool tapAndDragEnabled;
    public bool twoFingerTapEnabled;
    public bool rightClickZoneEnabled;
    public bool mouseAccelSettingHonored;
    public bool panEnabled;
    public bool zoomEnabled;
    public bool scrollDirectionReversed;
    public bool Reserved2;
    public TOUCHPAD_SENSITIVITY_LEVEL sensitivityLevel;
    public uint cursorSpeed;
    public uint feedbackIntensity;
    public uint clickForceSensitivity;
    public uint rightClickZoneWidth;
    public uint rightClickZoneHeight;
}

public class Touchpad32Functions
{
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfo", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref TOUCHPAD pvParam, uint fWinIni);
}
'@
        }
        'MousePrecision' {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class MousePrecision
{
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfo", SetLastError = true)]
    public static extern bool SystemParametersInfoGet(uint action, uint param, IntPtr vparam, uint fWinIni);
    public const UInt32 SPI_GETMOUSE = 0x0003;

    [DllImport("user32.dll", EntryPoint = "SystemParametersInfo", SetLastError = true)]
    public static extern bool SystemParametersInfoSet(uint action, uint param, IntPtr vparam, uint fWinIni);
    public const UInt32 SPI_SETMOUSE = 0x0004;

    public const uint SPIF_SENDCHANGE = 0x02;

    public static bool ToggleEnhancePointerPrecision(bool b)
    {
        int[] mouseParams = new int[3];
        GCHandle handle = GCHandle.Alloc(mouseParams, GCHandleType.Pinned);
        try
        {
            // Get the current values.
            SystemParametersInfoGet(SPI_GETMOUSE, 0, handle.AddrOfPinnedObject(), 0);
            // Modify the acceleration value as directed.
            mouseParams[2] = b ? 1 : 0;
            // Update the system setting.
            return SystemParametersInfoSet(SPI_SETMOUSE, 0, handle.AddrOfPinnedObject(), SPIF_SENDCHANGE);
        }
        catch
        {
            // Get the last Win32 error code.
            int errorCode = Marshal.GetLastWin32Error();
            Console.WriteLine("Error: " + errorCode);
            return false;
        }
        finally
        {
            handle.Free();
        }
    }
}
'@
        }
        'PrimaryButton' {
            $type = Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool SwapMouseButton(bool swap);
'@ -Name 'NativeMethods' -Namespace 'PInvoke' -PassThru

        }
    }

    if ($type) {
        # Used for smaller input functions.
        return $type
    }
}

function Get-TouchpadSettings {
    param (
        [Parameter()]
        [int] $VersionNumber = 1,

        [Parameter()]
        [string] $AssemblyName = 'Touchpad32Functions'
    )

    if (-not (Test-Assembly -AssemblyName $AssemblyName)) {
        Import-Type -AssemblyName $AssemblyName
    }

    $touchpad = New-Object TOUCHPAD
    $touchpad.versionNumber = $VersionNumber

    # TODO: Does not work, error code 87. See: https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-
    # TODO: Might also require checking if touchpad is present on machine, and if result can be captured as C++ acts different
    $result = [Touchpad32Functions]::SystemParametersInfo(0x00AE, 0, [ref]$touchpad, 0) # SPI_GETTOUCHPADPARAMETERS
    $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($err -ne 0) {
        throw [System.ComponentModel.Win32Exception]::new($err)
    }

    # TODO: Convert object?
    return $result
}

function Set-EnhancePointerPrecision {
    param (
        [switch] $Enable
    )

    if (-not (Test-Assembly -AssemblyName 'MousePrecision')) {
        Import-Type -AssemblyName 'MousePrecision'
    }

    [void][MousePrecision]::ToggleEnhancePointerPrecision($Enable.IsPresent)

    # Write the registry key for the MouseSpeed value.
    $pointerPrecisionValue = $Enable.IsPresent ? 1 : 0
    if (-not (DoesRegistryKeyPropertyExist -Path $global:MousePath -Name 'MouseSpeed')) {
        New-ItemProperty -Path $global:MousePath -Name 'MouseSpeed' -Value $pointerPrecisionValue -PropertyType DWord | Out-Null
    }
    Set-ItemProperty -Path $global:MousePath -Name 'MouseSpeed' -Value $pointerPrecisionValue
}

function Set-PrimaryButton {
    param (
        [switch] $Enable
    )

    if (-not (Test-Assembly -AssemblyName 'PrimaryButton')) {
        $swapButtons = Import-Type -AssemblyName 'PrimaryButton'
    }

    # Use $false for right-handed users, $true for left-handed users.
    [void]$swapButtons::SwapMouseButton($Enable.IsPresent)
}

function Set-MouseSetting {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PrimaryButton] $PrimaryButton,

        [Parameter(Mandatory)]
        [int] $CursorSpeed,

        [Parameter()]
        [nullable[bool]] $PointerPrecision,

        [Parameter()]
        [nullable[bool]] $RollMouseScroll,

        [Parameter()]
        [int] $LinesToScroll,

        [Parameter()]
        [nullable[bool]] $ScrollInactiveWindows,

        [Parameter()]
        [ScrollDirection] $ScrollDirection
    )

    switch ($PrimaryButton) {
        'Left' {
            # Still making sure registry is set otherwise Test() will not work.
            if (-not (DoesRegistryKeyPropertyExist -Path $global:MousePath -Name 'SwapMouseButtons')) {
                New-ItemProperty -Path $global:MousePath -Name 'SwapMouseButtons' -Value 0 -PropertyType DWord | Out-Null
            }
            Set-ItemProperty -Path $global:MousePath -Name 'SwapMouseButtons' -Value 0
            Set-PrimaryButton -Enable:$false
        }
        'Right' {
            if (-not (DoesRegistryKeyPropertyExist -Path $global:MousePath -Name 'SwapMouseButtons')) {
                New-ItemProperty -Path $global:MousePath -Name 'SwapMouseButtons' -Value 1 -PropertyType DWord | Out-Null
            }
            Set-ItemProperty -Path $global:MousePath -Name 'SwapMouseButtons' -Value 1
            Set-PrimaryButton -Enable:$true
        }
    }

    if ($null -ne $PointerPrecision) {
        Set-EnhancePointerPrecision -Enable:$PointerPrecision
    }
}
#endregion Functions

#region Classes
[DscResource()]
class USB {
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [nullable[bool]] $ConnectionNotifications
    [DscProperty()]
    [nullable[bool]] $SlowChargingNotification
    [DscProperty()]
    [nullable[bool]] $BatterySaver

    static hidden [string] $ConnectionNotificationsProperty = 'NotifyOnUsbErrors'
    static hidden [string] $SlowChargingNotificationProperty = 'NotifyOnWeakCharger'
    static hidden [string] $BatterySaverProperty = 'AttemptRecoveryFromUsbPowerDrain'

    [USB] Get() {
        $currentState = [USB]::new()
        $currentState.ConnectionNotifications = [USB]::GetConnectionNotificationStatus()
        $currentState.SlowChargingNotification = [USB]::GetSlowChargingNotificationStatus()
        $currentState.BatterySaver = [USB]::GetBatterySaverStatus()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.ConnectionNotifications) -and ($this.ConnectionNotifications -ne $currentState.ConnectionNotifications)) {
            return $false
        }

        if (($null -ne $this.SlowChargingNotification) -and ($this.SlowChargingNotification -ne $currentState.SlowChargingNotification)) {
            return $false
        }

        if (($null -ne $this.BatterySaver) -and ($this.BatterySaver -ne $currentState.BatterySaver)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            if ($null -ne $this.ConnectionNotifications) {
                if (-not (DoesRegistryKeyPropertyExist -Path $global:USBShellPath -Name ([USB]::ConnectionNotificationsProperty))) {
                    New-ItemProperty -Path $global:USBShellPath -Name ([USB]::ConnectionNotificationsProperty) -Value ([int]$this.ConnectionNotifications) -PropertyType DWord | Out-Null
                }
                Set-ItemProperty -Path $global:USBShellPath -Name ([USB]::ConnectionNotificationsProperty) -Value ([int]$this.ConnectionNotifications)
            }

            if ($null -ne $this.SlowChargingNotification) {
                if (-not (DoesRegistryKeyPropertyExist -Path $global:USBShellPath -Name ([USB]::SlowChargingNotificationProperty))) {
                    New-ItemProperty -Path $global:USBShellPath -Name ([USB]::SlowChargingNotificationProperty) -Value ([int]$this.SlowChargingNotification) -PropertyType DWord | Out-Null
                }
                Set-ItemProperty -Path $global:USBShellPath -Name ([USB]::SlowChargingNotificationProperty) -Value ([int]$this.SlowChargingNotification)
            }

            if ($null -ne $this.BatterySaver) {
                if (-not (DoesRegistryKeyPropertyExist -Path $global:USBMachinePath -Name ([USB]::BatterySaverProperty))) {
                    New-ItemProperty -Path $global:USBMachinePath -Name ([USB]::BatterySaverProperty) -Value ([int]$this.BatterySaver) -PropertyType DWord | Out-Null
                }
                Set-ItemProperty -Path $global:USBMachinePath -Name ([USB]::BatterySaverProperty) -Value ([int]$this.BatterySaver)
            }
        }
    }

    #region USB helper functions
    static [bool] GetConnectionNotificationStatus() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:USBShellPath -Name ([USB]::ConnectionNotificationsProperty))) {
            return $true
        } else {
            $ConnectionNotificationsValue = (Get-ItemProperty -Path $global:USBShellPath -Name ([USB]::ConnectionNotificationsProperty)).NotifyOnUsbErrors
            return ($ConnectionNotificationsValue -eq 1)
        }
    }

    static [bool] GetSlowChargingNotificationStatus() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:USBShellPath -Name ([USB]::SlowChargingNotificationProperty))) {
            return $true
        } else {
            $SlowChargingNotificationValue = (Get-ItemProperty -Path $global:USBShellPath -Name ([USB]::SlowChargingNotificationProperty)).NotifyOnWeakCharger
            return ($SlowChargingNotificationValue -eq 1)
        }
    }

    static [bool] GetBatterySaverStatus() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:USBMachinePath -Name ([USB]::BatterySaverProperty))) {
            return $false # It is not enabled by default if the registry key does not exist.
        } else {
            $BatterySaverValue = (Get-ItemProperty -Path $global:USBMachinePath -Name ([USB]::BatterySaverProperty)).AttemptRecoveryFromUsbPowerDrain
            return ($BatterySaverValue -eq 1)
        }
    }
    #endregion USB helper functions
}

[DscResource()]
class PenWindowsInk {
    [DscProperty(Key)]
    [FingerTipFont] $FingerTipFont

    [DscProperty()]
    [nullable[bool]] $WriteFingerTip

    static hidden [string] $FingerTipFontProperty = 'LatinFontName'
    static hidden [string] $WriteFingerTipProperty = 'EnableInkingWithTouch'

    PenWindowsInk() {
        $this.FingerTipFont = [PenWindowsInk]::GetFingerTipFont()
        $this.WriteFingerTip = [PenWindowsInk]::GetWriteFingertipStatus()
    }

    [PenWindowsInk] Get() {
        $currentState = [PenWindowsInk]::new()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.FingerTipFont) -and ($this.FingerTipFont -ne $currentState.FingerTipFont)) {
            return $false
        }

        if (($null -ne $this.WriteFingerTip) -and ($this.WriteFingerTip -ne $currentState.WriteFingerTip)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            if ($null -ne $this.FingerTipFont) {
                # Don't use enums in the registry, use the actual string value.
                $FingerTipValue = switch ($this.FingerTipFont) {
                    'InkFree' { 'Ink Free' }
                    'SegoeUI' { 'Segoe UI' }
                    default { 'Ink Free' }
                }

                if (-not (DoesRegistryKeyPropertyExist -Path $global:TabletTipPath -Name ([PenWindowsInk]::FingerTipFontProperty))) {
                    New-ItemProperty -Path $global:TabletTipPath -Name ([PenWindowsInk]::FingerTipFontProperty) -Value $FingerTipValue -PropertyType String | Out-Null
                }
                Set-ItemProperty -Path $global:TabletTipPath -Name ([PenWindowsInk]::FingerTipFontProperty) -Value $FingerTipValue
            }

            if ($null -ne $this.WriteFingerTip) {
                if (-not (DoesRegistryKeyPropertyExist -Path $global:TabletTipPath -Name ([PenWindowsInk]::WriteFingerTipProperty))) {
                    New-ItemProperty -Path $global:TabletTipPath -Name ([PenWindowsInk]::WriteFingerTipProperty) -Value ([int]$this.WriteFingerTip) -PropertyType DWord | Out-Null
                }
                Set-ItemProperty -Path $global:TabletTipPath -Name ([PenWindowsInk]::WriteFingerTipProperty) -Value ([int]$this.WriteFingerTip)
            }
        }
    }

    #region PenWindowsInk helper functions
    static [FingerTipFont] GetFingerTipFont() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:TabletTipPath -Name ([PenWindowsInk]::FingerTipFontProperty))) {
            return [FingerTipFont]::InkFree
        } else {
            $FingerTipValue = switch (((Get-ItemProperty -Path $global:TabletTipPath -Name ([PenWindowsInk]::FingerTipFontProperty)).LatinFontName)) {
                'Ink Free' { [FingerTipFont]::InkFree }
                'Segoe UI' { [FingerTipFont]::SegoeUI }
                default { [FingerTipFont]::InkFree }
            }

            return $FingerTipValue
        }
    }

    static [bool] GetWriteFingertipStatus() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:TabletTipPath -Name ([PenWindowsInk]::WriteFingertipProperty))) {
            return $true
        } else {
            $WriteWFingertipValue = (Get-ItemProperty -Path $global:TabletTipPath -Name ([PenWindowsInk]::WriteFingerTipProperty)).EnableInkingWithTouch
            return ($WriteWFingertipValue -eq 1)
        }
    }
    #endregion PenWindowsInk helper functions
}

[DscResource()]
class Mouse {

    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [PrimaryButton] $PrimaryButton

    [DscProperty()]
    [int] $CursorSpeed

    [DscProperty()]
    [nullable[bool]] $PointerPrecision

    [DscProperty()]
    [nullable[bool]] $RollMouseScroll

    [DscProperty()]
    [int] $LinesToScroll

    [DscProperty()]
    [nullable[bool]] $ScrollInactiveWindows

    [DscProperty()]
    [ScrollDirection] $ScrollDirection

    static hidden [string] $PrimaryButtonProperty = 'SwapMouseButtons'
    static hidden [string] $CursorSpeedProperty = 'MouseSensitivity'
    static hidden [string] $PointerPrecisionProperty = 'MouseSpeed'
    static hidden [string] $LinesToScrollProperty = 'WheelScrollLines'
    static hidden [string] $ScrollInactiveWindowsProperty = 'MouseWheelRouting'
    static hidden [string] $ScrollDirectionProperty = 'ReverseMouseWheelDirection'

    Mouse() {
    }

    [Mouse] Get() {
        $currentState = [Mouse]::new()
        $currentState.PrimaryButton = [Mouse]::GetPrimaryMouseStatus()
        $currentState.CursorSpeed = [Mouse]::GetCursorSpeed()
        $currentState.PointerPrecision = [Mouse]::GetPointerPrecisionStatus()
        # Capture the RollMouseScroll and LinesToScroll values in a hashtable.
        $roleMouseStatus = [Mouse]::GetRollMouseScrollStatus()
        # Set the values.
        $currentState.RollMouseScroll = $roleMouseStatus.RollMouseScroll
        $currentState.LinesToScroll = $roleMouseStatus.LinesToScroll
        $currentState.ScrollInactiveWindows = [Mouse]::GetScrollInactiveWindowsStatus()
        $currentState.ScrollDirection = [Mouse]::GetScrollDirectionStatus()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.PrimaryButton -ne $this.PrimaryButton) {
            return $false
        }

        if ((0 -eq $currentState.CursorSpeed) -and ($currentState.CursorSpeed -ne $this.CursorSpeed)) {
            return $false
        }

        if (($null -ne $this.PointerPrecision) -and ($this.PointerPrecision -ne $currentState.PointerPrecision)) {
            return $false
        }

        if (($null -ne $this.RollMouseScroll) -and ($this.RollMouseScroll -ne $currentState.RollMouseScroll)) {
            return $false
        }

        if ((0 -eq $currentState.LinesToScroll) -and ($this.LinesToScroll -ne $currentState.LinesToScroll)) {
            return $false
        }

        if ($currentState.ScrollDirection -ne $this.ScrollDirection) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            Set-MouseSetting -PrimaryButton $this.PrimaryButton `
                -CursorSpeed $this.CursorSpeed `
                -PointerPrecision $this.PointerPrecision `
                -RollMouseScroll $this.RollMouseScroll `
                -LinesToScroll $this.LinesToScroll `
                -ScrollInactiveWindows $this.ScrollInactiveWindows `
                -ScrollDirection $this.ScrollDirection
        }
    }

    #region Mouse helper functions
    static [PrimaryButton] GetPrimaryMouseStatus() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:MousePath -Name ([Mouse]::PrimaryButtonProperty))) {
            return [PrimaryButton]::Left
        } else {
            $MouseButtonValue = (Get-ItemProperty -Path $global:MousePath -Name ([Mouse]::PrimaryButtonProperty)).SwapMouseButtons
            return (($MouseButtonValue -eq 0) ? [PrimaryButton]::Left : [PrimaryButton]::Right)
        }
    }

    static [int] GetCursorSpeed() {
        $CursorSpeedValue = (Get-ItemPropertyValue -Path $global:MousePath -Name ([Mouse]::CursorSpeedProperty) -ErrorAction SilentlyContinue) # MouseSensitivity should always be present
        if ($null -eq $CursorSpeedValue) {
            $CursorSpeedValue = 10
        }

        return $CursorSpeedValue
    }

    static [bool] GetPointerPrecisionStatus() {
        # Note: MouseThreshold1 and MouseThreshold2 are also set but not checked here.
        $PointerPrecisionValue = (Get-ItemPropertyValue -Path $global:MousePath -Name ([Mouse]::PointerPrecisionProperty) -ErrorAction SilentlyContinue) # MouseSpeed should always be present
        if ($null -eq $PointerPrecisionValue) {
            $PointerPrecisionValue = 1
        }

        return ($PointerPrecisionValue -eq 1)
    }

    static [hashtable] GetRollMouseScrollStatus() {
        $RollMouseScrollValue = (Get-ItemPropertyValue -Path $global:DesktopPath -Name ([Mouse]::LinesToScrollProperty) -ErrorAction SilentlyContinue) # WheelScrollLines should always be present
        if ($null -eq $RollMouseScrollValue) {
            throw [System.Configuration.ConfigurationException]::new("'{0}' could not be found. Please make sure the key exists in the registry." -f ([Mouse]::RollMouseScrollProperty))
        }

        return @{
            'RollMouseScroll' = ($RollMouseScrollValue -gt 0) # If it is -1, it means single line scrolling
            'LinesToScroll'   = $RollMouseScrollValue
        }
    }

    static [bool] GetScrollInactiveWindowsStatus() {
        $ScrollInactiveWindowsValue = (Get-ItemPropertyValue -Path $global:DesktopPath -Name ([Mouse]::ScrollInactiveWindowsProperty) -ErrorAction SilentlyContinue)

        if ($null -eq $ScrollInactiveWindowsValue) {
            return $true
        }

        return ($ScrollInactiveWindowsValue -eq 2)
    }

    static [ScrollDirection] GetScrollDirectionStatus() {
        $ScrollDirectionValue = switch ((Get-ItemPropertyValue -Path $global:MousePath -Name ([Mouse]::ScrollDirectionProperty) -ErrorAction SilentlyContinue)) {
            0 { [ScrollDirection]::Down }
            1 { [ScrollDirection]::Up }
            default { [ScrollDirection]::Down }
        }

        return $ScrollDirectionValue
    }
    #endregion Mouse helper functions
}

# TODO: Does not work (yet). Check comments in Get-TouchpadSettings function.
# [DscResource()]
# class Touchpad {
#     [DscProperty(Key)]
#     [string]$DeviceID

#     [Touchpad] Get() {
#         $currentState = [Touchpad]::new()

#         return $currentState
#     }

#     [bool] Test() {
#         $currentState = $this.Get()

#         return $true
#     }

#     [void] Set() {

#     }

#     #region Touchpad helper functions
#     static [PSObject] GetTouchpadSettingStatus() {
#         $TouchpadSetting = Get-TouchpadSetting

#         return $TouchpadSetting
#     }
#     #endregion Touchpad helper functions
# }
#endregion Classes
