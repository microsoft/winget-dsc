# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

enum Ensure {
    Absent
    Present
}

enum TextSize {
    KeepCurrentValue
    Small
    Medium
    Large
    ExtraLarge
}

enum MagnificationValue {
    KeepCurrentValue
    None
    Low
    Medium
    High
}

enum PointerSize {
    KeepCurrentValue
    Normal
    Medium
    Large
    ExtraLarge
}

[Flags()] enum StickyKeysOptions {
    # https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-stickykeys
    None = 0x00000000 # 0
    Active = 0x00000001 # 1
    Available = 0x00000002 # 2
    HotkeyActive = 0x00000004 # 4
    ConfirmHotkey = 0x00000008 # 8
    HotkeySound = 0x00000010# 16
    VisualIndicator = 0x00000020 # 32
    AudibleFeedback = 0x00000040 # 64
    TriState = 0x00000080 # 128
    TwoKeysOff = 0x00000100 # 256
}

[Flags()] enum ToggleKeysOptions {
    # https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-togglekeys
    None = 0x00000000 # 0
    Active = 0x00000001 # 1
    Available = 0x00000002 # 2
    HotkeyActive = 0x00000004 # 4
    ConfirmHotkey = 0x00000008 # 8
    HotkeySound = 0x00000010# 16
    VisualIndicator = 0x00000020 # 32
}

[Flags()] enum FilterKeysOptions {
    # https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-filterkeys
    None = 0x00000000 # 0
    Active = 0x00000001 # 1
    Available = 0x00000002 # 2
    HotkeyActive = 0x00000004 # 4
    ConfirmHotkey = 0x00000008 # 8
    HotkeySound = 0x00000010# 16
    VisualIndicator = 0x00000020 # 32
    AudibleFeedback = 0x00000040 # 64
}

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:AccessibilityRegistryPath = 'HKCU:\Software\Microsoft\Accessibility\'
    $global:MagnifierRegistryPath = 'HKCU:\Software\Microsoft\ScreenMagnifier\'
    $global:PointerRegistryPath = 'HKCU:\Control Panel\Cursors\'
    $global:ControlPanelAccessibilityRegistryPath = 'HKCU:\Control Panel\Accessibility\'
    $global:AudioRegistryPath = 'HKCU:\Software\Microsoft\Multimedia\Audio\'
    $global:PersonalizationRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
    $global:NTAccessibilityRegistryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility\'
    $global:CursorIndicatorAccessibilityRegistryPath = 'HKCU:\Software\Microsoft\Accessibility\CursorIndicator\'
    $global:ControlPanelDesktopRegistryPath = 'HKCU:\Control Panel\Desktop'
    $global:StickyKeysRegistryPath = 'HKCU:\Control Panel\Accessibility\StickyKeys'
    $global:ToggleKeysRegistryPath = 'HKCU:\Control Panel\Accessibility\ToggleKeys'
    $global:FilterKeysRegistryPath = 'HKCU:\Control Panel\Accessibility\Keyboard Response'
    $global:EyeControlRegistryPath = 'HKCU:\Software\Microsoft\input\EC\'
} else {
    $global:AccessibilityRegistryPath = $global:MagnifierRegistryPath = $global:PointerRegistryPath = $global:ControlPanelAccessibilityRegistryPath = $global:AudioRegistryPath = $global:PersonalizationRegistryPath = $global:NTAccessibilityRegistryPath = $global:CursorIndicatorAccessibilityRegistryPath = $global:ControlPanelDesktopRegistryPath = $global:StickyKeysRegistryPath = $global:ToggleKeysRegistryPath = $global:FilterKeysRegistryPath = $global:EyeControlRegistryPath = $env:TestRegistryPath
}

<#
    .SYNOPSIS
        The `Text` DSC resource is used to manage the Windows text size accessibility setting.

    .DESCRIPTION
        The `Text` DSC resource configures the Windows text scaling factor, which controls
        the size of text across the system for accessibility purposes.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER Size
        The desired text size. Accepted values are `Small`, `Medium`, `Large`, or `ExtraLarge`.
        This is a key property. Defaults to `KeepCurrentValue`.

    .PARAMETER SizeValue
        A read-only property indicating the current numeric text scale factor. This property is not configurable.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name Text -Method Set -Property @{
            Size = 'Large'
        }

        This example sets the Windows text size to Large.
#>
[DSCResource()]
class Text {
    [DscProperty(Key)] [TextSize] $Size = [TextSize]::KeepCurrentValue
    [DscProperty(NotConfigurable)] [int] $SizeValue

    hidden [string] $TextScaleFactor = 'TextScaleFactor'

    [Text] Get() {
        $currentState = [Text]::new()

        if (-not(DoesRegistryKeyPropertyExist -Path $global:AccessibilityRegistryPath -Name $this.TextScaleFactor)) {
            $currentState.Size = [TextSize]::Small
            $currentState.SizeValue = 96
        } else {
            $currentState.SizeValue = [int](Get-ItemPropertyValue -Path $global:AccessibilityRegistryPath -Name $this.TextScaleFactor)
            $currentSize = switch ($currentState.sizeValue) {
                96 { [TextSize]::Small }
                120 { [TextSize]::Medium }
                144 { [TextSize]::Large }
                256 { [TextSize]::ExtraLarge }
            }

            if ($null -ne $currentSize) {
                $currentState.Size = $currentSize
            }
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($this.Size -ne [TextSize]::KeepCurrentValue -and $this.Size -ne $currentState.Size) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.Size -ne [TextSize]::KeepCurrentValue) {
            $desiredSize = switch ([TextSize]($this.Size)) {
                Small { 96 }
                Medium { 120 }
                Large { 144 }
                ExtraLarge { 256 }
            }

            Set-ItemProperty -Path $global:AccessibilityRegistryPath -Name $this.TextScaleFactor -Value $desiredSize -Type DWORD
        }
    }
}

<#
    .SYNOPSIS
        The `Magnifier` DSC resource is used to manage Windows Magnifier accessibility settings.

    .DESCRIPTION
        The `Magnifier` DSC resource configures the Windows Magnifier tool, including its
        magnification level and zoom increment.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER Magnification
        The magnification preset to apply. Accepted values are `None`, `Low`, `Medium`, or `High`.
        This is a key property. Defaults to `KeepCurrentValue`.

    .PARAMETER ZoomIncrement
        The zoom increment percentage. This is a mandatory property. Defaults to `25`.

    .PARAMETER StartMagnify
        Specifies whether to start the Magnifier application after applying settings. Defaults to `$false`.

    .PARAMETER MagnificationLevel
        A read-only property indicating the current magnification level in percent. This property is not configurable.

    .PARAMETER ZoomIncrementLevel
        A read-only property indicating the current zoom increment value. This property is not configurable.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name Magnifier -Method Set -Property @{
            Magnification = 'Medium'
            ZoomIncrement = 25
        }

        This example sets the Windows Magnifier zoom to the Medium preset with 25% increments.
#>
[DSCResource()]
class Magnifier {
    [DscProperty(Key)] [MagnificationValue] $Magnification = [MagnificationValue]::KeepCurrentValue
    [DscProperty(Mandatory)] [int] $ZoomIncrement = 25
    [DscProperty()] [bool] $StartMagnify = $false
    [DscProperty(NotConfigurable)] [int] $MagnificationLevel
    [DscProperty(NotConfigurable)] [int] $ZoomIncrementLevel

    hidden [string] $MagnificationProperty = 'Magnification'
    hidden [string] $ZoomIncrementProperty = 'ZoomIncrement'

    [Magnifier] Get() {
        $currentState = [Magnifier]::new()

        if (-not(DoesRegistryKeyPropertyExist -Path $global:MagnifierRegistryPath -Name $this.MagnificationProperty)) {
            $currentState.Magnification = [MagnificationValue]::None
            $currentState.MagnificationLevel = 0
        } else {
            $currentState.MagnificationLevel = (Get-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.MagnificationProperty).Magnification
            $currentMagnification = switch ($currentState.MagnificationLevel) {
                0 { [MagnificationValue]::None }
                100 { [MagnificationValue]::Low }
                200 { [MagnificationValue]::Medium }
                300 { [MagnificationValue]::High }
                default { [MagnificationValue]::KeepCurrentValue }
            }

            $currentState.Magnification = $currentMagnification
        }

        if (-not(DoesRegistryKeyPropertyExist -Path $global:MagnifierRegistryPath -Name $this.ZoomIncrementProperty)) {
            $currentState.ZoomIncrement = 25
            $currentState.ZoomIncrementLevel = 25
        } else {
            $currentState.ZoomIncrementLevel = (Get-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.ZoomIncrementProperty).ZoomIncrement
            $currentState.ZoomIncrement = $currentState.ZoomIncrementLevel
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($this.Magnification -ne [MagnificationValue]::KeepCurrentValue -and $this.Magnification -ne $currentState.Magnification) {
            return $false
        }
        if ($this.ZoomIncrement -ne $currentState.ZoomIncrement) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if (-not (Test-Path -Path $global:MagnifierRegistryPath)) {
            New-Item -Path $global:MagnifierRegistryPath -Force | Out-Null
        }

        if ($this.Magnification -ne [MagnificationValue]::KeepCurrentValue) {
            $desiredMagnification = switch ([MagnificationValue]($this.Magnification)) {
                None { 0 }
                Low { 100 }
                Medium { 200 }
                High { 300 }
            }

            Set-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.MagnificationProperty -Value $desiredMagnification -Type DWORD
        }

        $currentState = $this.Get()

        if ($this.ZoomIncrement -ne $currentState.ZoomIncrement) {
            Set-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.ZoomIncrementProperty -Value $this.ZoomIncrement -Type DWORD
        }

        if (($this.StartMagnify) -and (($null -eq (Get-Process -Name 'Magnify' -ErrorAction SilentlyContinue)))) {
            Start-Process 'C:\Windows\System32\Magnify.exe'
        }
    }
}

<#
    .SYNOPSIS
        The `MousePointer` DSC resource is used to manage the Windows mouse pointer size accessibility setting.

    .DESCRIPTION
        The `MousePointer` DSC resource configures the size of the Windows mouse cursor
        for accessibility purposes.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER PointerSize
        The desired mouse pointer size. Accepted values are `Normal`, `Medium`, `Large`, or `ExtraLarge`.
        This is a key property. Defaults to `KeepCurrentValue`.

    .PARAMETER PointerSizeValue
        A read-only property indicating the current pointer size value. This property is not configurable.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name MousePointer -Method Set -Property @{
            PointerSize = 'Large'
        }

        This example sets the Windows mouse pointer size to Large.
#>
[DSCResource()]
class MousePointer {
    [DscProperty(Key)] [PointerSize] $PointerSize = [PointerSize]::KeepCurrentValue
    [DscProperty(NotConfigurable)] [string] $PointerSizeValue

    hidden [string] $PointerSizeProperty = 'CursorBaseSize'

    [MousePointer] Get() {
        $currentState = [MousePointer]::new()

        if (-not(DoesRegistryKeyPropertyExist -Path $global:PointerRegistryPath -Name $this.PointerSizeProperty)) {
            $currentState.PointerSize = [PointerSize]::Normal
            $currentState.PointerSizeValue = '32'
        } else {
            $currentState.PointerSizeValue = (Get-ItemProperty -Path $global:PointerRegistryPath -Name $this.PointerSizeProperty).CursorBaseSize
            $currentSize = switch ($currentState.PointerSizeValue) {
                '32' { [PointerSize]::Normal }
                '96' { [PointerSize]::Medium }
                '144' { [PointerSize]::Large }
                '256' { [PointerSize]::ExtraLarge }
                default { [PointerSize]::KeepCurrentValue }
            }

            $currentState.PointerSize = $currentSize
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($this.PointerSize -ne [PointerSize]::KeepCurrentValue -and $this.PointerSize -ne $currentState.PointerSize) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.PointerSize -ne [PointerSize]::KeepCurrentValue) {
            $desiredSize = switch ([PointerSize]($this.PointerSize)) {
                Normal { '32' }
                Medium { '96' }
                Large { '144' }
                ExtraLarge { '256' }
            }

            if (-not (Test-Path -Path $global:PointerRegistryPath)) {
                New-Item -Path $global:PointerRegistryPath -Force | Out-Null
            }

            Set-ItemProperty -Path $global:PointerRegistryPath -Name $this.PointerSizeProperty -Value $desiredSize
        }
    }
}

<#
    .SYNOPSIS
        The `VisualEffect` DSC resource is used to manage Windows visual accessibility settings.

    .DESCRIPTION
        The `VisualEffect` DSC resource configures visual accessibility options including
        always-visible scrollbars, transparency effects, and notification message duration.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER SID
        The security identifier. This is a key property and should not be set manually.

    .PARAMETER AlwaysShowScrollbars
        Specifies whether scrollbars should always be visible.

    .PARAMETER TransparencyEffects
        Specifies whether transparency effects are disabled (set `$true` to disable transparency).

    .PARAMETER MessageDurationInSeconds
        The duration in seconds that notification messages are displayed. Must be between 5 and 300.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name VisualEffect -Method Set -Property @{
            AlwaysShowScrollbars     = $true
            TransparencyEffects      = $false
            MessageDurationInSeconds = 5
        }

        This example enables always-visible scrollbars and sets the notification duration to 5 seconds.
#>
[DSCResource()]
class VisualEffect {
    # Key required. Do not set.
    [DscProperty(Key)] [string] $SID
    [DscProperty()] [nullable[bool]] $AlwaysShowScrollbars
    [DscProperty()] [nullable[bool]] $TransparencyEffects
    [DscProperty()] [int] $MessageDurationInSeconds

    static hidden [string] $DynamicScrollbarsProperty = 'DynamicScrollbars'
    static hidden [string] $TransparencySettingProperty = 'EnableTransparency'
    static hidden [string] $MessageDurationProperty = 'MessageDuration'

    static [bool] GetShowDynamicScrollbarsStatus() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::DynamicScrollbarsProperty))) {
            return $false
        } else {
            $dynamicScrollbarsValue = (Get-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::DynamicScrollbarsProperty)).DynamicScrollbars
            return ($dynamicScrollbarsValue -eq 0)
        }
    }

    static [bool] GetTransparencyStatus() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty))) {
            return $false
        } else {
            $TransparencySetting = (Get-ItemProperty -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty)).EnableTransparency
            return ($TransparencySetting -eq 0)
        }
    }

    static [int] GetMessageDuration() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::MessageDurationProperty))) {
            return 5
        } else {
            $MessageDurationSetting = (Get-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::MessageDurationProperty)).MessageDuration
            return $MessageDurationSetting
        }
    }

    [VisualEffect] Get() {
        $currentState = [VisualEffect]::new()
        $currentState.AlwaysShowScrollbars = [VisualEffect]::GetShowDynamicScrollbarsStatus()
        $currentState.TransparencyEffects = [VisualEffect]::GetTransparencyStatus()
        $currentState.MessageDurationInSeconds = [VisualEffect]::GetMessageDuration()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if (($null -ne $this.AlwaysShowScrollbars) -and ($this.AlwaysShowScrollbars -ne $currentState.AlwaysShowScrollbars)) {
            return $false
        }
        if (($null -ne $this.TransparencyEffects) -and ($this.TransparencyEffects -ne $currentState.TransparencyEffects)) {
            return $false
        }
        if ((0 -ne $this.MessageDurationInSeconds) -and ($this.MessageDurationInSeconds -ne $currentState.MessageDurationInSeconds)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not $this.Test()) {
            if (-not (Test-Path -Path $global:ControlPanelAccessibilityRegistryPath)) {
                New-Item -Path $global:ControlPanelAccessibilityRegistryPath -Force | Out-Null
            }
            if ($null -ne $this.AlwaysShowScrollbars) {
                $dynamicScrollbarValue = if ($this.AlwaysShowScrollbars) { 0 } else { 1 }
                Set-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::DynamicScrollbarsProperty) -Value $dynamicScrollbarValue
            }
            if ($null -ne $this.TransparencyEffects) {
                $transparencyValue = if ($this.TransparencyEffects) { 0 } else { 1 }

                if (-not (DoesRegistryKeyPropertyExist -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty))) {
                    New-ItemProperty -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty) -Value $transparencyValue -PropertyType DWord
                }
                Set-ItemProperty -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty) -Value $transparencyValue
            }
            if (0 -ne $this.MessageDurationInSeconds) {
                $min = 5
                $max = 300
                if ($this.MessageDurationInSeconds -notin $min..$max) {
                    throw "MessageDurationInSeconds must be between $min and $max. Value $($this.MessageDurationInSeconds) was provided."
                }
                Set-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::MessageDurationProperty) -Value $this.MessageDurationInSeconds
            }
        }
    }
}

<#
    .SYNOPSIS
        The `Audio` DSC resource is used to manage Windows audio accessibility settings.

    .DESCRIPTION
        The `Audio` DSC resource configures the Windows mono audio accessibility setting,
        which combines stereo audio into a single mono channel for users who are hard of hearing.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER SID
        The security identifier. This is a key property and should not be set manually.

    .PARAMETER EnableMonoAudio
        Specifies whether mono audio should be enabled. Defaults to `$false`.

    .PARAMETER RestartService
        Specifies whether to restart the Windows Audio service after applying changes. Defaults to `$false`.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name Audio -Method Set -Property @{
            EnableMonoAudio = $true
        }

        This example enables mono audio on Windows.
#>
[DSCResource()]
class Audio {
    # Key required. Do not set.
    [DscProperty(Key)] [string] $SID
    [DscProperty()] [bool] $EnableMonoAudio = $false
    [DscProperty()] [bool] $RestartService = $false

    static hidden [string] $EnableMonoAudioProperty = 'AccessibilityMonoMixState'

    static [bool] GetEnableMonoAudioStatus() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:AudioRegistryPath -Name ([Audio]::EnableMonoAudioProperty))) {
            return $false
        } else {
            $AudioMonoSetting = (Get-ItemProperty -Path $global:AudioRegistryPath -Name ([Audio]::EnableMonoAudioProperty)).AccessibilityMonoMixState
            return ($AudioMonoSetting -eq 1)
        }
    }

    [Audio] Get() {
        $currentState = [Audio]::new()
        $currentState.EnableMonoAudio = [Audio]::GetEnableMonoAudioStatus()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($this.EnableMonoAudio -ne $currentState.EnableMonoAudio) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not $this.Test()) {
            if (-not (Test-Path -Path $global:AudioRegistryPath)) {
                New-Item -Path $global:AudioRegistryPath -Force | Out-Null
            }

            $monoAudioValue = $this.EnableMonoAudio ? 1 : 0

            Set-ItemProperty -Path $global:AudioRegistryPath -Name ([Audio]::EnableMonoAudioProperty) -Value $monoAudioValue

            if ($this.RestartService) {
                Restart-Service -Name 'Audiosrv' -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

<#
    .SYNOPSIS
        The `TextCursor` DSC resource is used to manage Windows text cursor accessibility settings.

    .DESCRIPTION
        The `TextCursor` DSC resource configures the Windows text cursor indicator, including
        its visibility, size, color, and thickness.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER SID
        The security identifier. This is a key property and should not be set manually.

    .PARAMETER IndicatorStatus
        Enables or disables the text cursor indicator accessibility feature.

    .PARAMETER IndicatorSize
        The size of the text cursor indicator. Must be between 1 and 20.

    .PARAMETER IndicatorColor
        The color of the text cursor indicator as an integer value.

    .PARAMETER Thickness
        The thickness of the text cursor. Must be between 1 and 20.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name TextCursor -Method Set -Property @{
            IndicatorStatus = $true
            Thickness       = 3
        }

        This example enables the text cursor indicator and sets the cursor thickness to 3.
#>
[DSCResource()]
class TextCursor {
    # Key required. Do not set.
    [DscProperty(Key)] [string] $SID
    [DscProperty()] [nullable[bool]] $IndicatorStatus
    [DscProperty()] [int] $IndicatorSize
    [DscProperty()] [int] $IndicatorColor
    [DscProperty()] [int] $Thickness

    static hidden [string] $IndicatorStatusProperty = 'Configuration'
    static hidden [string] $IndicatorStatusValue = 'cursorindicator'
    static hidden [string] $IndicatorSizeProperty = 'IndicatorType'
    static hidden [string] $IndicatorColorProperty = 'IndicatorColor'
    static hidden [string] $ThicknessProperty = 'CaretWidth'


    static [bool] GetIndicatorStatus() {
        $indicatorStatusArgs = @{  Path = $global:NTAccessibilityRegistryPath; Name = ([TextCursor]::IndicatorStatusProperty) }
        if (-not(DoesRegistryKeyPropertyExist @indicatorStatusArgs)) {
            return $false
        } else {
            $textCursorSetting = (Get-ItemProperty @indicatorStatusArgs).Configuration
            return ($textCursorSetting -eq ([TextCursor]::IndicatorStatusValue))
        }
    }

    static [int] GetIndicatorSize() {
        $indicatorSizeArgs = @{  Path = $global:CursorIndicatorAccessibilityRegistryPath; Name = ([TextCursor]::IndicatorSizeProperty) }
        if (-not(DoesRegistryKeyPropertyExist @indicatorSizeArgs)) {
            return 1
        } else {
            $textCursorSetting = (Get-ItemProperty @indicatorSizeArgs).IndicatorType
            return $textCursorSetting
        }
    }

    static [int] GetIndicatorColor() {
        $indicatorColorArgs = @{  Path = $global:CursorIndicatorAccessibilityRegistryPath; Name = ([TextCursor]::IndicatorColorProperty) }
        if (-not(DoesRegistryKeyPropertyExist @indicatorColorArgs)) {
            return $false
        } else {
            $textCursorSetting = (Get-ItemProperty @indicatorColorArgs).IndicatorColor
            return $textCursorSetting
        }
    }

    static [int] GetThickness() {
        $thicknessArgs = @{ Path = $global:ControlPanelDesktopRegistryPath; Name = ([TextCursor]::ThicknessProperty); }
        if (-not(DoesRegistryKeyPropertyExist @thicknessArgs)) {
            return 1
        } else {
            $textCursorSetting = (Get-ItemProperty @thicknessArgs).CaretWidth
            return $textCursorSetting
        }
    }

    [TextCursor] Get() {
        $currentState = [TextCursor]::new()
        $currentState.IndicatorStatus = [TextCursor]::GetIndicatorStatus()
        $currentState.IndicatorSize = [TextCursor]::GetIndicatorSize()
        $currentState.IndicatorColor = [TextCursor]::GetIndicatorColor()
        $currentState.Thickness = [TextCursor]::GetThickness()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if (($null -ne $this.IndicatorStatus) -and ($this.IndicatorStatus -ne $currentState.IndicatorStatus)) {
            return $false
        }
        if ((0 -ne $this.IndicatorSize) -and ($this.IndicatorSize -ne $currentState.IndicatorSize)) {
            return $false
        }
        if ((0 -ne $this.IndicatorColor) -and ($this.IndicatorColor -ne $currentState.IndicatorColor)) {
            return $false
        }
        if ((0 -ne $this.Thickness) -and ($this.Thickness -ne $currentState.Thickness)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not $this.Test()) {
            if ($null -ne $this.IndicatorStatus) {
                $indicatorStatusArgs = @{ Path = $global:NTAccessibilityRegistryPath; Name = ([TextCursor]::IndicatorStatusProperty); }
                $textCursorValue = if ($this.IndicatorStatus) { ([TextCursor]::IndicatorStatusValue) } else { '' }
                Set-ItemProperty @indicatorStatusArgs -Value $textCursorValue
            }

            if (0 -ne $this.IndicatorSize) {
                $indicatorSizeArgs = @{  Path = $global:CursorIndicatorAccessibilityRegistryPath; Name = ([TextCursor]::IndicatorSizeProperty) }
                $min = 1
                $max = 20
                if ($this.IndicatorSize -notin $min..$max) {
                    throw "IndicatorSize must be between $min and $max. Value $($this.IndicatorSize) was provided."
                }
                if (-not (DoesRegistryKeyPropertyExist @indicatorSizeArgs)) {
                    New-ItemProperty @indicatorSizeArgs -Value $this.IndicatorSize -PropertyType DWord
                }
                Set-ItemProperty @indicatorSizeArgs -Value $this.IndicatorSize
            }

            if (0 -ne $this.IndicatorColor) {
                $indicatorColorArgs = @{  Path = $global:CursorIndicatorAccessibilityRegistryPath; Name = ([TextCursor]::IndicatorColorProperty) }
                $min = 1
                $max = 99999999
                if ($this.IndicatorColor -notin $min..$max) {
                    throw "IndicatorColor must be between $min and $max. Value $($this.IndicatorColor) was provided."
                }
                if (-not (DoesRegistryKeyPropertyExist @indicatorColorArgs)) {
                    New-ItemProperty @indicatorColorArgs -Value $this.IndicatorColor -PropertyType DWord
                }
                Set-ItemProperty @indicatorColorArgs -Value $this.IndicatorColor
            }

            if (0 -ne $this.Thickness) {
                $thicknessArgs = @{ Path = $global:ControlPanelDesktopRegistryPath; Name = ([TextCursor]::ThicknessProperty); }
                $min = 1
                $max = 20
                if ($this.Thickness -notin $min..$max) {
                    throw "Thickness must be between $min and $max. Value $($this.Thickness) was provided."
                }
                Set-ItemProperty @thicknessArgs -Value $this.Thickness
            }
        }
    }
}

<#
    .SYNOPSIS
        The `StickyKeys` DSC resource is used to manage the Windows Sticky Keys accessibility feature.

    .DESCRIPTION
        The `StickyKeys` DSC resource configures the Sticky Keys accessibility feature, which
        allows modifier keys (Shift, Ctrl, Alt) to remain active after being pressed once, enabling
        users to type keyboard shortcuts one key at a time.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER SID
        The security identifier. This is a key property and should not be set manually.

    .PARAMETER Active
        Specifies whether Sticky Keys is currently active.

    .PARAMETER Available
        Specifies whether Sticky Keys is available to be toggled.

    .PARAMETER HotkeyActive
        Specifies whether the Sticky Keys keyboard shortcut (pressing Shift 5 times) is active.

    .PARAMETER ConfirmOnHotkeyActivation
        Specifies whether a confirmation dialog is shown when Sticky Keys is activated via hotkey.

    .PARAMETER HotkeySound
        Specifies whether a sound plays when Sticky Keys hotkey is used.

    .PARAMETER VisualIndicator
        Specifies whether a visual indicator is shown when Sticky Keys is active.

    .PARAMETER AudibleFeedback
        Specifies whether an audible tone plays when a modifier key is pressed.

    .PARAMETER TriState
        Specifies whether modifier keys can be locked by pressing them twice.

    .PARAMETER TwoKeysOff
        Specifies whether Sticky Keys is turned off when two keys are pressed simultaneously.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name StickyKeys -Method Set -Property @{
            Active     = $true
            TwoKeysOff = $true
        }

        This example enables Sticky Keys and configures it to turn off when two keys are pressed simultaneously.
#>
[DSCResource()]
class StickyKeys {
    # Key required. Do not set.
    [DscProperty(Key)] [string] $SID
    [DscProperty()] [nullable[bool]] $Active
    [DscProperty()] [nullable[bool]] $Available
    [DscProperty()] [nullable[bool]] $HotkeyActive
    [DscProperty()] [nullable[bool]] $ConfirmOnHotkeyActivation
    [DscProperty()] [nullable[bool]] $HotkeySound
    [DscProperty()] [nullable[bool]] $VisualIndicator
    [DscProperty()] [nullable[bool]] $AudibleFeedback
    [DscProperty()] [nullable[bool]] $TriState
    [DscProperty()] [nullable[bool]] $TwoKeysOff

    static hidden [string] $SettingsProperty = 'Flags'

    static [System.Enum] GetCurrentFlags() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:StickyKeysRegistryPath -Name ([StickyKeys]::SettingsProperty))) {
            return [StickyKeysOptions]::None
        } else {
            $StickyKeysFlags = [System.Enum]::Parse('StickyKeysOptions', (Get-ItemPropertyValue -Path $global:StickyKeysRegistryPath -Name ([StickyKeys]::SettingsProperty)))
            return $StickyKeysFlags
        }
    }

    [StickyKeys] Get() {
        $currentFlags = [StickyKeys]::GetCurrentFlags()

        $currentState = [StickyKeys]::new()
        $currentState.Active = $currentFlags.HasFlag([StickyKeysOptions]::Active)
        $currentState.Available = $currentFlags.HasFlag([StickyKeysOptions]::Available)
        $currentState.HotkeyActive = $currentFlags.HasFlag([StickyKeysOptions]::HotkeyActive)
        $currentState.ConfirmOnHotkeyActivation = $currentFlags.HasFlag([StickyKeysOptions]::ConfirmHotkey)
        $currentState.HotkeySound = $currentFlags.HasFlag([StickyKeysOptions]::HotkeySound)
        $currentState.VisualIndicator = $currentFlags.HasFlag([StickyKeysOptions]::VisualIndicator)
        $currentState.AudibleFeedback = $currentFlags.HasFlag([StickyKeysOptions]::AudibleFeedback)
        $currentState.TriState = $currentFlags.HasFlag([StickyKeysOptions]::TriState)
        $currentState.TwoKeysOff = $currentFlags.HasFlag([StickyKeysOptions]::TwoKeysOff)

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.Active) -and ($this.Active -ne $currentState.Active)) {
            return $false
        }

        if (($null -ne $this.Available) -and ($this.Available -ne $currentState.Available)) {
            return $false
        }

        if (($null -ne $this.HotkeyActive) -and ($this.HotkeyActive -ne $currentState.HotkeyActive)) {
            return $false
        }

        if (($null -ne $this.ConfirmOnHotkeyActivation) -and ($this.ConfirmOnHotkeyActivation -ne $currentState.ConfirmOnHotkeyActivation)) {
            return $false
        }

        if (($null -ne $this.HotkeySound) -and ($this.HotkeySound -ne $currentState.HotkeySound)) {
            return $false
        }

        if (($null -ne $this.VisualIndicator) -and ($this.VisualIndicator -ne $currentState.VisualIndicator)) {
            return $false
        }

        if (($null -ne $this.AudibleFeedback) -and ($this.AudibleFeedback -ne $currentState.AudibleFeedback)) {
            return $false
        }

        if (($null -ne $this.TriState) -and ($this.TriState -ne $currentState.TriState)) {
            return $false
        }

        if (($null -ne $this.TwoKeysOff) -and ($this.TwoKeysOff -ne $currentState.TwoKeysOff)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        # Only make changes if changes are needed
        if (-not $this.Test()) {
            # If a value isn't set in the DSC, it should remain unchanged, to do this we need the current flags
            $flags = [StickyKeys]::GetCurrentFlags()

            if ($null -ne $this.Active) {
                $flags = $this.Active ? $flags -bor [StickyKeysOptions]::Active : $flags -band (-bnot [StickyKeysOptions]::Active)
            }

            if ($null -ne $this.Available) {
                $flags = $this.Available ? $flags -bor [StickyKeysOptions]::Available : $flags -band (-bnot [StickyKeysOptions]::Available)
            }

            if ($null -ne $this.HotkeyActive) {
                $flags = $this.HotkeyActive ? $flags -bor [StickyKeysOptions]::HotkeyActive : $flags -band (-bnot [StickyKeysOptions]::HotkeyActive)
            }

            if ($null -ne $this.ConfirmOnHotkeyActivation) {
                $flags = $this.ConfirmOnHotkeyActivation ? $flags -bor [StickyKeysOptions]::ConfirmHotkey : $flags -band (-bnot [StickyKeysOptions]::ConfirmHotkey)
            }

            if ($null -ne $this.HotkeySound) {
                $flags = $this.HotkeySound ? $flags -bor [StickyKeysOptions]::HotkeySound : $flags -band (-bnot [StickyKeysOptions]::HotkeySound)
            }

            if ($null -ne $this.VisualIndicator) {
                $flags = $this.VisualIndicator ? $flags -bor [StickyKeysOptions]::VisualIndicator : $flags -band (-bnot [StickyKeysOptions]::VisualIndicator)
            }

            if ($null -ne $this.AudibleFeedback) {
                $flags = $this.AudibleFeedback ? $flags -bor [StickyKeysOptions]::AudibleFeedback : $flags -band (-bnot [StickyKeysOptions]::AudibleFeedback)
            }

            if ($null -ne $this.TriState) {
                $flags = $this.TriState ? $flags -bor [StickyKeysOptions]::TriState : $flags -band (-bnot [StickyKeysOptions]::TriState)
            }

            if ($null -ne $this.TwoKeysOff) {
                $flags = $this.TwoKeysOff ? $flags -bor [StickyKeysOptions]::TwoKeysOff : $flags -band (-bnot [StickyKeysOptions]::TwoKeysOff)
            }

            # Set the value in the registry
            Set-ItemProperty -Path $global:StickyKeysRegistryPath -Name ([StickyKeys]::SettingsProperty) -Value $flags.GetHashCode()
        }
    }
}

<#
    .SYNOPSIS
        The `ToggleKeys` DSC resource is used to manage the Windows Toggle Keys accessibility feature.

    .DESCRIPTION
        The `ToggleKeys` DSC resource configures the Toggle Keys accessibility feature, which
        plays a sound when the Caps Lock, Num Lock, or Scroll Lock keys are pressed.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER SID
        The security identifier. This is a key property and should not be set manually.

    .PARAMETER Active
        Specifies whether Toggle Keys is currently active.

    .PARAMETER Available
        Specifies whether Toggle Keys is available to be toggled.

    .PARAMETER HotkeyActive
        Specifies whether the Toggle Keys keyboard shortcut (holding Num Lock for 5 seconds) is active.

    .PARAMETER ConfirmOnHotkeyActivation
        Specifies whether a confirmation dialog is shown when Toggle Keys is activated via hotkey.

    .PARAMETER HotkeySound
        Specifies whether a sound plays when Toggle Keys hotkey is used.

    .PARAMETER VisualIndicator
        Specifies whether a visual indicator is shown when Toggle Keys is active.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name ToggleKeys -Method Set -Property @{
            Active = $true
        }

        This example enables the Toggle Keys feature.
#>
[DSCResource()]
class ToggleKeys {
    # Key required. Do not set.
    [DscProperty(Key)] [string] $SID
    [DscProperty()] [nullable[bool]] $Active
    [DscProperty()] [nullable[bool]] $Available
    [DscProperty()] [nullable[bool]] $HotkeyActive
    [DscProperty()] [nullable[bool]] $ConfirmOnHotkeyActivation
    [DscProperty()] [nullable[bool]] $HotkeySound
    [DscProperty()] [nullable[bool]] $VisualIndicator

    static hidden [string] $SettingsProperty = 'Flags'

    static [System.Enum] GetCurrentFlags() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ToggleKeysRegistryPath -Name ([ToggleKeys]::SettingsProperty))) {
            return [ToggleKeysOptions]::None
        } else {
            $ToggleKeysFlags = [System.Enum]::Parse('ToggleKeysOptions', (Get-ItemPropertyValue -Path $global:StickyKeysRegistryPath -Name ([StickyKeys]::SettingsProperty)))
            return $ToggleKeysFlags
        }
    }

    [ToggleKeys] Get() {
        $currentFlags = [ToggleKeys]::GetCurrentFlags()

        $currentState = [ToggleKeys]::new()
        $currentState.Active = $currentFlags.HasFlag([ToggleKeysOptions]::Active)
        $currentState.Available = $currentFlags.HasFlag([ToggleKeysOptions]::Available)
        $currentState.HotkeyActive = $currentFlags.HasFlag([ToggleKeysOptions]::HotkeyActive)
        $currentState.ConfirmOnHotkeyActivation = $currentFlags.HasFlag([ToggleKeysOptions]::ConfirmHotkey)
        $currentState.HotkeySound = $currentFlags.HasFlag([ToggleKeysOptions]::HotkeySound)
        $currentState.VisualIndicator = $currentFlags.HasFlag([ToggleKeysOptions]::VisualIndicator)

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.Active) -and ($this.Active -ne $currentState.Active)) {
            return $false
        }

        if (($null -ne $this.Available) -and ($this.Available -ne $currentState.Available)) {
            return $false
        }

        if (($null -ne $this.HotkeyActive) -and ($this.HotkeyActive -ne $currentState.HotkeyActive)) {
            return $false
        }

        if (($null -ne $this.ConfirmOnHotkeyActivation) -and ($this.ConfirmOnHotkeyActivation -ne $currentState.ConfirmOnHotkeyActivation)) {
            return $false
        }

        if (($null -ne $this.HotkeySound) -and ($this.HotkeySound -ne $currentState.HotkeySound)) {
            return $false
        }

        if (($null -ne $this.VisualIndicator) -and ($this.VisualIndicator -ne $currentState.VisualIndicator)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        # Only make changes if changes are needed
        if (-not $this.Test()) {
            # If a value isn't set in the DSC, it should remain unchanged, to do this we need the current flags
            $flags = [ToggleKeys]::GetCurrentFlags()

            if ($null -ne $this.Active) {
                $flags = $this.Active ? $flags -bor [ToggleKeysOptions]::Active : $flags -band (-bnot [ToggleKeysOptions]::Active)
            }

            if ($null -ne $this.Available) {
                $flags = $this.Available ? $flags -bor [ToggleKeysOptions]::Available : $flags -band (-bnot [ToggleKeysOptions]::Available)
            }

            if ($null -ne $this.HotkeyActive) {
                $flags = $this.HotkeyActive ? $flags -bor [ToggleKeysOptions]::HotkeyActive : $flags -band (-bnot [ToggleKeysOptions]::HotkeyActive)
            }

            if ($null -ne $this.ConfirmOnHotkeyActivation) {
                $flags = $this.ConfirmOnHotkeyActivation ? $flags -bor [ToggleKeysOptions]::ConfirmHotkey : $flags -band (-bnot [ToggleKeysOptions]::ConfirmHotkey)
            }

            if ($null -ne $this.HotkeySound) {
                $flags = $this.HotkeySound ? $flags -bor [ToggleKeysOptions]::HotkeySound : $flags -band (-bnot [ToggleKeysOptions]::HotkeySound)
            }

            if ($null -ne $this.VisualIndicator) {
                $flags = $this.VisualIndicator ? $flags -bor [ToggleKeysOptions]::VisualIndicator : $flags -band (-bnot [ToggleKeysOptions]::VisualIndicator)
            }

            # Set the value in the registry
            Set-ItemProperty -Path $global:ToggleKeysRegistryPath -Name ([ToggleKeys]::SettingsProperty) -Value $flags.GetHashCode()
        }
    }
}

<#
    .SYNOPSIS
        The `FilterKeys` DSC resource is used to manage the Windows Filter Keys accessibility feature.

    .DESCRIPTION
        The `FilterKeys` DSC resource configures the Filter Keys accessibility feature, which
        ignores brief or repeated keystrokes and slows the repeat rate to help users with
        hand tremors type more accurately.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER SID
        The security identifier. This is a key property and should not be set manually.

    .PARAMETER Active
        Specifies whether Filter Keys is currently active.

    .PARAMETER Available
        Specifies whether Filter Keys is available to be toggled.

    .PARAMETER HotkeyActive
        Specifies whether the Filter Keys keyboard shortcut (holding Right Shift for 8 seconds) is active.

    .PARAMETER ConfirmOnHotkeyActivation
        Specifies whether a confirmation dialog is shown when Filter Keys is activated via hotkey.

    .PARAMETER HotkeySound
        Specifies whether a sound plays when Filter Keys hotkey is used.

    .PARAMETER VisualIndicator
        Specifies whether a visual indicator is shown when Filter Keys is active.

    .PARAMETER AudibleFeedback
        Specifies whether an audible tone plays when a key is pressed or accepted.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name FilterKeys -Method Set -Property @{
            Active = $true
        }

        This example enables the Filter Keys feature.
#>
[DSCResource()]
class FilterKeys {
    # Key required. Do not set.
    [DscProperty(Key)] [string] $SID
    [DscProperty()] [nullable[bool]] $Active
    [DscProperty()] [nullable[bool]] $Available
    [DscProperty()] [nullable[bool]] $HotkeyActive
    [DscProperty()] [nullable[bool]] $ConfirmOnHotkeyActivation
    [DscProperty()] [nullable[bool]] $HotkeySound
    [DscProperty()] [nullable[bool]] $VisualIndicator
    [DscProperty()] [nullable[bool]] $AudibleFeedback

    static hidden [string] $SettingsProperty = 'Flags'

    static [System.Enum] GetCurrentFlags() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:FilterKeysRegistryPath -Name ([FilterKeys]::SettingsProperty))) {
            return [FilterKeysOptions]::None
        } else {
            $FilterKeysFlags = [System.Enum]::Parse('FilterKeysOptions', (Get-ItemPropertyValue -Path $global:FilterKeysRegistryPath -Name ([FilterKeys]::SettingsProperty)))
            return $FilterKeysFlags
        }
    }

    [FilterKeys] Get() {
        $currentFlags = [FilterKeys]::GetCurrentFlags()

        $currentState = [FilterKeys]::new()
        $currentState.Active = $currentFlags.HasFlag([FilterKeysOptions]::Active)
        $currentState.Available = $currentFlags.HasFlag([FilterKeysOptions]::Available)
        $currentState.HotkeyActive = $currentFlags.HasFlag([FilterKeysOptions]::HotkeyActive)
        $currentState.ConfirmOnHotkeyActivation = $currentFlags.HasFlag([FilterKeysOptions]::ConfirmHotkey)
        $currentState.HotkeySound = $currentFlags.HasFlag([FilterKeysOptions]::HotkeySound)
        $currentState.VisualIndicator = $currentFlags.HasFlag([FilterKeysOptions]::VisualIndicator)
        $currentState.AudibleFeedback = $currentFlags.HasFlag([FilterKeysOptions]::AudibleFeedback)

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.Active) -and ($this.Active -ne $currentState.Active)) {
            return $false
        }

        if (($null -ne $this.Available) -and ($this.Available -ne $currentState.Available)) {
            return $false
        }

        if (($null -ne $this.HotkeyActive) -and ($this.HotkeyActive -ne $currentState.HotkeyActive)) {
            return $false
        }

        if (($null -ne $this.ConfirmOnHotkeyActivation) -and ($this.ConfirmOnHotkeyActivation -ne $currentState.ConfirmOnHotkeyActivation)) {
            return $false
        }

        if (($null -ne $this.HotkeySound) -and ($this.HotkeySound -ne $currentState.HotkeySound)) {
            return $false
        }

        if (($null -ne $this.VisualIndicator) -and ($this.VisualIndicator -ne $currentState.VisualIndicator)) {
            return $false
        }

        if (($null -ne $this.AudibleFeedback) -and ($this.AudibleFeedback -ne $currentState.AudibleFeedback)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        # Only make changes if changes are needed
        if (-not $this.Test()) {
            # If a value isn't set in the DSC, it should remain unchanged, to do this we need the current flags
            $flags = [FilterKeys]::GetCurrentFlags()

            if ($null -ne $this.Active) {
                $flags = $this.Active ? $flags -bor [FilterKeysOptions]::Active : $flags -band (-bnot [FilterKeysOptions]::Active)
            }

            if ($null -ne $this.Available) {
                $flags = $this.Available ? $flags -bor [FilterKeysOptions]::Available : $flags -band (-bnot [FilterKeysOptions]::Available)
            }

            if ($null -ne $this.HotkeyActive) {
                $flags = $this.HotkeyActive ? $flags -bor [FilterKeysOptions]::HotkeyActive : $flags -band (-bnot [FilterKeysOptions]::HotkeyActive)
            }

            if ($null -ne $this.ConfirmOnHotkeyActivation) {
                $flags = $this.ConfirmOnHotkeyActivation ? $flags -bor [FilterKeysOptions]::ConfirmHotkey : $flags -band (-bnot [FilterKeysOptions]::ConfirmHotkey)
            }

            if ($null -ne $this.HotkeySound) {
                $flags = $this.HotkeySound ? $flags -bor [FilterKeysOptions]::HotkeySound : $flags -band (-bnot [FilterKeysOptions]::HotkeySound)
            }

            if ($null -ne $this.VisualIndicator) {
                $flags = $this.VisualIndicator ? $flags -bor [FilterKeysOptions]::VisualIndicator : $flags -band (-bnot [FilterKeysOptions]::VisualIndicator)
            }

            if ($null -ne $this.AudibleFeedback) {
                $flags = $this.AudibleFeedback ? $flags -bor [FilterKeysOptions]::AudibleFeedback : $flags -band (-bnot [FilterKeysOptions]::AudibleFeedback)
            }

            # Set the value in the registry
            Set-ItemProperty -Path $global:FilterKeysRegistryPath -Name ([FilterKeys]::SettingsProperty) -Value $flags.GetHashCode()
        }
    }
}

<#
    .SYNOPSIS
        The `EyeControl` DSC resource is used to enable or disable the Windows Eye Control accessibility feature.

    .DESCRIPTION
        The `EyeControl` DSC resource configures the Windows Eye Control accessibility feature,
        which enables users to control Windows using only their eyes with a supported eye tracking device.

        ## Requirements

        * Target machine must be running Windows.

    .PARAMETER Ensure
        Specifies whether Eye Control should be enabled (`Present`) or disabled (`Absent`).
        This is a key property.

    .EXAMPLE
        Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Accessibility -Name EyeControl -Method Set -Property @{
            Ensure = 'Present'
        }

        This example enables the Windows Eye Control accessibility feature.
#>
[DscResource()]
class EyeControl {
    [DscProperty(Key)] [Ensure] $Ensure
    hidden [string] $SettingsProperty = 'Enabled'

    [EyeControl] Get() {
        $currentState = [EyeControl]::new()

        if (-not(DoesRegistryKeyPropertyExist -Path $global:EyeControlRegistryPath -Name $this.SettingsProperty)) {
            $currentState.Ensure = [Ensure]::Absent
        } else {
            $currentState.Ensure = [int]((Get-ItemPropertyValue -Path $global:EyeControlRegistryPath -Name $this.SettingsProperty) -eq 1)
        }

        return $currentState
    }

    [bool] Test() {
        return $this.Get().Ensure -eq $this.Ensure
    }

    [void] Set() {
        # Only make changes if changes are needed
        if ($this.Test()) { return }
        if (-not (DoesRegistryKeyPropertyExist -Path $global:EyeControlRegistryPath -Name $this.SettingsProperty)) {
            New-ItemProperty -Path $global:EyeControlRegistryPath -Name $this.SettingsProperty -PropertyType DWord
        }
        Set-ItemProperty -Path $global:EyeControlRegistryPath -Name $this.SettingsProperty -Value $([int]$this.Ensure)
    }
}

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
#endregion Functions
