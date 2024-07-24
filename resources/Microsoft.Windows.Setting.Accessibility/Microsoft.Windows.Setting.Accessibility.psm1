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

enum AnimationEffectsState {
    KeepCurrentValue
	Enabled
	Disabled
}

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:AccessibilityRegistryPath = 'HKCU:\Software\Microsoft\Accessibility\'
    $global:MagnifierRegistryPath = 'HKCU:\Software\Microsoft\ScreenMagnifier\'
    $global:PointerRegistryPath = 'HKCU:\Control Panel\Cursors\'
    $global:AnimationEffectsSettingsRegistryPath = 'HKCU:\Control Panel\Desktop\'
}
else {
    $global:AccessibilityRegistryPath = $global:MagnifierRegistryPath = $global:PointerRegistryPath = $env:TestRegistryPath
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

        if (-not(DoesRegistryKeyPropertyExist -Path $global:MagnifierRegistryPath -Name $this.Magnification)) {
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

        return $false
    }

    [void] Set() {
        if ($this.Magnification -ne [MagnificationValue]::KeepCurrentValue) {
            $desiredMagnification = switch ([MagnificationValue]($this.Magnification)) {
                None { 0 }
                Low { 100 }
                Medium { 200 }
                High { 300 }
            }

            if (-not (Test-Path -Path $global:MagnifierRegistryPath)) {
                New-Item -Path $global:MagnifierRegistryPath -Force | Out-Null
            }

            Set-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.MagnificationProperty -Value $desiredMagnification -Type DWORD
        }

        if ($this.ZoomIncrement -ne (Get-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.ZoomIncrementProperty).ZoomIncrement) {
            Set-ItemProperty -Path $global:MagnifierRegistryPath -Name $this.ZoomIncrementProperty -Value $this.ZoomIncrement -Type DWORD
        }

        if (($this.StartMagnify) -and (($null -eq (Get-Process -Name 'Magnify' -ErrorAction SilentlyContinue)))) {
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
class AnimationEffects {
	#Need to verify the Animation Effects setting toggle on the Accessibility page changes when these are updated, or find the setting to update that also.
    [DscProperty(Key)] [AnimationEffectsState] $AnimationEffectsState = [AnimationEffectsState]::KeepCurrentValue
    [DscProperty(NotConfigurable)] [int] $SmoothScrollListBoxes
    [DscProperty(NotConfigurable)] [int] $SlideOpenComboBoxes
    [DscProperty(NotConfigurable)] [int] $FadeOrSlideMenusIntoView
    [DscProperty(NotConfigurable)] [int] $ShowShadowsUnderMousePointer
    [DscProperty(NotConfigurable)] [int] $FadeOrSlideToolTipsIntoView
    [DscProperty(NotConfigurable)] [int] $FadeOutMenuItemsAfterClicking
    [DscProperty(NotConfigurable)] [int] $ShowShadowsUnderWindows

    hidden [string] $AnimationEffectsProperty = 'UserPreferencesMask'
	#These settings are stored alongside other settings in a bitmask.

    [AnimationEffects] Get() {
        $currentState = [AnimationEffectsState]::new()

		$AnimationState = (Get-ItemPropertyValue -Path $global:AnimationEffectsSettingsRegistryPath -Name $AnimationEffectsProperty) | %{[System.Convert]::ToString($_,2).PadLeft(8,'0')} #Get-ItemPropertyValue converts hex to int, so need to complete converting to binary.

		#Decode bitmask string array as char array grid
		#1001ABC0 
		#00D1EF10 
		#00000G11

		$SmoothScrollListBoxes = $AnimationState[0][4] #A
		$SlideOpenComboBoxes = $AnimationState[0][5] #B
		$FadeOrSlideMenusIntoView = $AnimationState[0][6] #C

		$ShowShadowsUnderMousePointer = $AnimationState[1][2] #D
		$FadeOrSlideToolTipsIntoView = $AnimationState[1][4] #E
		$FadeOutMenuItemsAfterClicking = $AnimationState[1][5] #F

		$ShowShadowsUnderWindows = $AnimationState[2][5] #G

		if ($ShowShadowsUnderWindows -eq 0 
		-AND $SlideOpenComboBoxes -eq 0 
		-AND $FadeOrSlideMenusIntoView -eq 0 
		-AND $ShowShadowsUnderMousePointer -eq 0 
		-AND $FadeOrSlideToolTipsIntoView -eq 0 
		-AND $FadeOutMenuItemsAfterClicking -eq 0 
		-AND $ShowShadowsUnderWindows -eq 0) {
			$currentState = [AnimationEffectsState]::Disabled
		} else {
			$currentState = [AnimationEffectsState]::Enabled
		}

		return $currentState
	}

    [bool] Test() {
		$currentState = $this.Get()
		if ($this.AnimationEffectsState -ne [AnimationEffectsState]::KeepCurrentValue -and $this.AnimationEffectsState -ne $currentState.AnimationEffectsState) {
			return $false
		}

		return $true
    }

    [void] Set() {
		if ($this.AnimationEffectsState -ne [AnimationEffectsState]::KeepCurrentValue) {
            $desiredValue = switch ([AnimationEffectsState]($this.AnimationEffectsState)) {
                Enabled {1}
                Disabled {0}
            }

			$AnimationState = (Get-ItemPropertyValue -Path $global:AnimationEffectsSettingsRegistryPath -Name $AnimationEffectsProperty) | %{[System.Convert]::ToString($_,2).PadLeft(8,'0')} #Get-ItemPropertyValue converts hex to int, so need to complete converting to binary.
			#Recombine string array with desired state variables.
			#1001ABC0 
			#00D1EF10 
			#00000G11

			$AnimationState[0] = $AnimationState[0][0..3]+$desiredValue+$desiredValue+$desiredValue+$AnimationState[0][7] -join ""

			$AnimationState[1] = $AnimationState[1][0..1]+$desiredValue+$AnimationState[1][3]+$desiredValue+$desiredValue+$AnimationState[1][6..7] -join ""

			$AnimationState[2] = $AnimationState[2][0..4]+$desiredValue+$AnimationState[0][6..7] -join ""

			if (-not (Test-Path -Path $global:AnimationEffectsSettingsRegistryPath)) {
                New-Item -Path $global:AnimationEffectsSettingsRegistryPath -Force | Out-Null
			}

			Set-ItemProperty -Path $global:AnimationEffectsSettingsRegistryPath -Name $this.AnimationEffectsProperty -Value ($AnimationState | %{[convert]::ToInt32($_,2).ToString("X").PadLeft(2,'0')})
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
