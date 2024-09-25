# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

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

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:AccessibilityRegistryPath = 'HKCU:\Software\Microsoft\Accessibility\'
    $global:MagnifierRegistryPath = 'HKCU:\Software\Microsoft\ScreenMagnifier\'
    $global:PointerRegistryPath = 'HKCU:\Control Panel\Cursors\'
    $global:ControlPanelAccessibilityRegistryPath= 'HKCU:\Control Panel\Accessibility\'
    $global:AudioRegistryPath = 'HKCU:\Software\Microsoft\Multimedia\Audio\'
    $global:PersonalizationRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
}
else {
    $global:AccessibilityRegistryPath = $global:MagnifierRegistryPath = $global:PointerRegistryPath = $global:ControlPanelAccessibilityRegistryPath = $global:AudioRegistryPath = $global:PersonalizationRegistryPath = $env:TestRegistryPath
}


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
        }
        else {
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
        }
        else {
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
        }
        else {            
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
        if ($this.Test())
        {
            return
        }

        if (-not (Test-Path -Path $global:MagnifierRegistryPath))
        {
            New-Item -Path $global:MagnifierRegistryPath -Force | Out-Null
        }

        if ($this.Magnification -ne [MagnificationValue]::KeepCurrentValue)
        {
            $desiredMagnification = switch ([MagnificationValue]($this.Magnification))
            {
                None { 0 }
                Low { 100 }
                Medium { 200 }
                High { 300 }
            }

            Set-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.MagnificationProperty -Value $desiredMagnification -Type DWORD
        }

        $currentState = $this.Get()

        if ($this.ZoomIncrement -ne $currentState.ZoomIncrement)
        {
            Set-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.ZoomIncrementProperty -Value $this.ZoomIncrement -Type DWORD
        }

        if (($this.StartMagnify) -and (($null -eq (Get-Process -Name 'Magnify' -ErrorAction SilentlyContinue))))
        {
            Start-Process "C:\Windows\System32\Magnify.exe"
        }
    }
}

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
        }
        else {
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
                Medium {'96'}
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

[DSCResource()]
class VisualEffect
{
    # Key required. Do not set.
    [DscProperty(Key)] [string] $SID
    [DscProperty()] [nullable[bool]] $AlwaysShowScrollbars
    [DscProperty()] [nullable[bool]] $TransparencyEffects
    [DscProperty()] [int] $MessageDurationInSeconds

    static hidden [string] $DynamicScrollbarsProperty = 'DynamicScrollbars'
    static hidden [string] $TransparencySettingProperty = 'EnableTransparency'
    static hidden [string] $MessageDurationProperty = 'MessageDuration'

    static [bool] GetShowDynamicScrollbarsStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::DynamicScrollbarsProperty)))
        {
            return $false
        }
        else
        {
            $dynamicScrollbarsValue = (Get-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::DynamicScrollbarsProperty)).DynamicScrollbars
            return ($dynamicScrollbarsValue -eq 0)
        }        
    }

    static [bool] GetTransparencyStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty)))
        {
            return $false
        }
        else
        {
            $TransparencySetting = (Get-ItemProperty -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty)).EnableTransparency
            return ($TransparencySetting -eq 0)
        }
    }

    static [int] GetMessageDuration()
	{
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::MessageDurationProperty)))
        {
            return 5
        }
        else
        {
            $MessageDurationSetting = (Get-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::MessageDurationProperty)).MessageDuration
            return $MessageDurationSetting
        }
    }

    [VisualEffect] Get()
    {
        $currentState = [VisualEffect]::new()
        $currentState.AlwaysShowScrollbars = [VisualEffect]::GetShowDynamicScrollbarsStatus()
        $currentState.TransparencyEffects = [VisualEffect]::GetTransparencyStatus()
        $currentState.MessageDurationInSeconds = [VisualEffect]::GetMessageDuration()
        
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        if (($null -ne $this.AlwaysShowScrollbars) -and ($this.AlwaysShowScrollbars -ne $currentState.AlwaysShowScrollbars))
        {
            return $false
        }
        if (($null -ne $this.TransparencyEffects) -and ($this.TransparencyEffects -ne $currentState.TransparencyEffects))
        {
            return $false
        }
        if ((0 -ne $this.MessageDurationInSeconds) -and ($this.MessageDurationInSeconds -ne $currentState.MessageDurationInSeconds))
        {
            return $false
        }

        return $true
    }

    [void] Set()
    {
        if (-not $this.Test())
        {
            if (-not (Test-Path -Path $global:ControlPanelAccessibilityRegistryPath))
            {
                New-Item -Path $global:ControlPanelAccessibilityRegistryPath -Force | Out-Null
            }
            if ($null -ne $this.AlwaysShowScrollbars) 
            {
                $dynamicScrollbarValue = if ($this.AlwaysShowScrollbars) { 0 } else { 1 }
                Set-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::DynamicScrollbarsProperty) -Value $dynamicScrollbarValue
            }
            if ($null -ne $this.TransparencyEffects) 
            {
                $transparencyValue = if ($this.TransparencyEffects) { 0 } else { 1 }
				
                if (-not (DoesRegistryKeyPropertyExist -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty))) {
                    New-ItemProperty -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty) -Value $transparencyValue -PropertyType DWord
                }
                Set-ItemProperty -Path $global:PersonalizationRegistryPath -Name ([VisualEffect]::TransparencySettingProperty) -Value $transparencyValue 
            }
            if (0 -ne $this.MessageDurationInSeconds) 
            {
                $min = 5
                $max = 300
                $messageDurationValue = $this.MessageDurationInSeconds 
                if ($messageDurationValue -notin 5..300) 
                { 
                    throw "MessageDurationInSeconds must be between $min and $max. Value $messageDurationValue was provided." 
                }
                Set-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name ([VisualEffect]::MessageDurationProperty) -Value $messageDurationValue
            }
        }
    }
}

[DSCResource()]
class Audio
{
    # Key required. Do not set.
    [DscProperty(Key)] [string] $SID
    [DscProperty()] [bool] $EnableMonoAudio = $false

    static hidden [string] $EnableMonoAudioProperty = 'AccessibilityMonoMixState'

    static [bool] GetEnableMonoAudioStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:AudioRegistryPath -Name ([Audio]::EnableMonoAudioProperty)))
        {
            return $false
        }
        else
        {
            $AudioMonoSetting = (Get-ItemProperty -Path $global:AudioRegistryPath -Name ([Audio]::EnableMonoAudioProperty)).AccessibilityMonoMixState
            return ($AudioMonoSetting -eq 0)
        }        
    }

    [Audio] Get()
    {
        $currentState = [Audio]::new()
        $currentState.EnableMonoAudio = [Audio]::GetEnableMonoAudioStatus()
        
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        if ($this.EnableMonoAudio -ne $currentState.EnableMonoAudio)
        {
            return $false
        }

        return $true
    }

    [void] Set()
    {
        if (-not $this.Test())
        {
            if (-not (Test-Path -Path $global:AudioRegistryPath))
            {
                New-Item -Path $global:AudioRegistryPath -Force | Out-Null
            }

            $monoAudioValue = if ($this.EnableMonoAudio) { 0 } else { 1 }

            Set-ItemProperty -Path $global:AudioRegistryPath -Name ([Audio]::EnableMonoAudioProperty) -Value $monoAudioValue 
        }
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
    $itemProperty = Get-ItemProperty -Path $Path  -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $itemProperty
}
#endregion Functions