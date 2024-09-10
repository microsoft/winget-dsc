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
}
else {
    $global:AccessibilityRegistryPath = $global:MagnifierRegistryPath = $global:PointerRegistryPath = $global:ControlPanelAccessibilityRegistryPath = $env:TestRegistryPath
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
    [DscProperty()] [bool] $AlwaysShowScrollbars = $false
    [DscProperty()] [int] $MessageDurationSeconds = 5

    hidden [string] $DynamicScrollbarsProperty = 'DynamicScrollbars'
    hidden [string] $MessageDurationProperty = 'MessageDuration'

    [VisualEffect] Get()
    {
        $currentState = [VisualEffect]::new()

        if (-not(DoesRegistryKeyPropertyExist -Path $global:ControlPanelAccessibilityRegistryPath -Name $this.DynamicScrollbarsProperty))
        {
            $currentState.AlwaysShowScrollbars = $false
        }
        else
        {
            $dynamicScrollbarsValue = (Get-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name $this.DynamicScrollbarsProperty).DynamicScrollbars
            $currentState.AlwaysShowScrollbars = ($dynamicScrollbarsValue -eq 0)
        }

        if (-not(DoesRegistryKeyPropertyExist -Path $global:ControlPanelAccessibilityRegistryPath -Name $this.MessageDurationProperty)) {
        {
            $currentState.MessageDurationSeconds = $false
        }
        else
        {
            $AudioMonoSetting = (Get-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name $this.MessageDurationProperty).AccessibilityMonoMixState
            $currentState.MessageDurationSeconds = ($AudioMonoSetting -eq 0)
        }
        
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        if ($this.AlwaysShowScrollbars -ne $currentState.AlwaysShowScrollbars)
        {
            return $false
        }
        if ($this.MessageDurationSeconds -ne $currentState.MessageDurationSeconds)
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
            if (-not (Test-Path -Path $global:ControlPanelAccessibilityRegistryPath))
            {
                New-Item -Path $global:ControlPanelAccessibilityRegistryPath -Force | Out-Null
            }

            if (-not (Test-Path -Path $global:ControlPanelAccessibilityRegistryPath )) {
                New-Item -Path $global:ControlPanelAccessibilityRegistryPath  -Force | Out-Null
            }

            $dynamicScrollbarValue = $this.AlwaysShowScrollbars ? 0 : 1
            $dynamicScrollbarLowerValue = 5
            $dynamicScrollbarUpperValue = 300
            if ($this.MessageDurationSeconds -lt $dynamicScrollbarLowerValue) {
                $this.MessageDurationSeconds = $dynamicScrollbarLowerValue
                Write-Output "Valid values are $dynamicScrollbarLowerValue-$dynamicScrollbarUpperValue. Setting to $dynamicScrollbarLowerValue seconds."
            }
            if ($this.MessageDurationSeconds -gt $dynamicScrollbarUpperValue) {
                $this.MessageDurationSeconds = $dynamicScrollbarUpperValue
                Write-Output "Valid values are $dynamicScrollbarLowerValue-$dynamicScrollbarUpperValue. Setting to $dynamicScrollbarUpperValue seconds."
            }

            Set-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name $this.DynamicScrollbarsProperty -Value $dynamicScrollbarValue            
            Set-ItemProperty -Path $global:ControlPanelAccessibilityRegistryPath -Name $this.MessageDurationProperty -Value $this.MessageDurationSeconds
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