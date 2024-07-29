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

enum BinarySettingState {
    KeepCurrentValue
	Enabled
	Disabled
}

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:AccessibilityRegistryPath = 'HKCU:\Software\Microsoft\Accessibility\'
    $global:MagnifierRegistryPath = 'HKCU:\Software\Microsoft\ScreenMagnifier\'
    $global:PointerRegistryPath = 'HKCU:\Control Panel\Cursors\'
    $global:AnimationEffectsRegistryPath = 'HKCU:\Control Panel\Desktop\'
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
    [DscProperty(Key)] [BinarySettingState] $SmoothScrollListBoxes = [BinarySettingState]::KeepCurrentValue
    [DscProperty()] [BinarySettingState] $SlideOpenComboBoxes = [BinarySettingState]::KeepCurrentValue
    [DscProperty()] [BinarySettingState] $FadeOrSlideMenusIntoView = [BinarySettingState]::KeepCurrentValue
    [DscProperty()] [BinarySettingState] $ShowShadowsUnderMousePointer = [BinarySettingState]::KeepCurrentValue
    [DscProperty()] [BinarySettingState] $FadeOrSlideToolTipsIntoView = [BinarySettingState]::KeepCurrentValue
    [DscProperty()] [BinarySettingState] $FadeOutMenuItemsAfterClicking = [BinarySettingState]::KeepCurrentValue
    [DscProperty()] [BinarySettingState] $ShowShadowsUnderWindows = [BinarySettingState]::KeepCurrentValue
    [DscProperty(NotConfigurable)] [AnimationEffects] $currentState

    [AnimationEffects] Get() {
        $this.currentState = [AnimationEffects]::new()

		$this.AnimationState = (Get-ItemPropertyValue -Path $global:AnimationEffectsRegistryPath -Name 'UserPreferencesMask') | %{[System.Convert]::ToString($_,2).PadLeft(8,'0')}

		If ($this.AnimationState[0][4] -eq 0) {
			$this.SmoothScrollListBoxes = [BinarySettingState]::Disabled
		} else {
			$this.SmoothScrollListBoxes = [BinarySettingState]::Enabled
		}

		If ($this.AnimationState[0][5] -eq 0) {
			$this.SlideOpenComboBoxes = [BinarySettingState]::Disabled
		} else {
			$this.SlideOpenComboBoxes = [BinarySettingState]::Enabled
		}

		If ($this.AnimationState[0][6] -eq 0) {
			$this.FadeOrSlideMenusIntoView = [BinarySettingState]::Disabled
		} else {
			$this.FadeOrSlideMenusIntoView = [BinarySettingState]::Enabled
		}

		If ($this.AnimationState[1][2] -eq 0) {
			$this.ShowShadowsUnderMousePointer = [BinarySettingState]::Disabled
		} else {
			$this.ShowShadowsUnderMousePointer = [BinarySettingState]::Enabled
		}

		If ($this.AnimationState[1][4] -eq 0) {
			$this.FadeOrSlideToolTipsIntoView = [BinarySettingState]::Disabled
		} else {
			$this.FadeOrSlideToolTipsIntoView = [BinarySettingState]::Enabled
		}

		If ($this.AnimationState[1][5] -eq 0) {
			$this.FadeOutMenuItemsAfterClicking = [BinarySettingState]::Disabled
		} else {
			$this.FadeOutMenuItemsAfterClicking = [BinarySettingState]::Enabled
		}

		If ($this.AnimationState[2][5] -eq 0) {
			$this.ShowShadowsUnderWindows = [BinarySettingState]::Disabled
		} else {
			$this.ShowShadowsUnderWindows = [BinarySettingState]::Enabled
		}

		if ($this.SmoothScrollListBoxes -eq [BinarySettingState]::Disabled -and 
		$this.SlideOpenComboBoxes -eq [BinarySettingState]::Disabled -and 
		$this.FadeOrSlideMenusIntoView -eq [BinarySettingState]::Disabled -and 
		$this.ShowShadowsUnderMousePointer -eq [BinarySettingState]::Disabled -and 
		$this.FadeOrSlideToolTipsIntoView -eq [BinarySettingState]::Disabled -and 
		$this.FadeOutMenuItemsAfterClicking -eq [BinarySettingState]::Disabled -and 
		$this.ShowShadowsUnderWindows -eq [BinarySettingState]::Disabled ) {
			$this.currentState = [BinarySettingState]::Disabled
		} else {
			$this.currentState = [BinarySettingState]::Enabled
		}

		return $this.currentState
	}

    [bool] Test() {
		$this.currentState = $this.Get()
		if ($this.SmoothScrollListBoxes -ne [BinarySettingState]::KeepCurrentValue -and
		$this.SmoothScrollListBoxes -ne $this.currentState.SmoothScrollListBoxes -and
		 $this.SlideOpenComboBoxes -ne [BinarySettingState]::KeepCurrentValue -and
		 $this.SlideOpenComboBoxes -ne $this.currentState.SlideOpenComboBoxes -and
		 $this.FadeOrSlideMenusIntoView -ne [BinarySettingState]::KeepCurrentValue -and
		 $this.FadeOrSlideMenusIntoView -ne $this.currentState.FadeOrSlideMenusIntoView -and
		 $this.ShowShadowsUnderMousePointer -ne [BinarySettingState]::KeepCurrentValue -and
		 $this.ShowShadowsUnderMousePointer -ne $this.currentState.ShowShadowsUnderMousePointer -and
		 $this.ShowShadowsUnderMousePointer -ne [BinarySettingState]::KeepCurrentValue -and
		 $this.ShowShadowsUnderMousePointer -ne $this.currentState.ShowShadowsUnderMousePointer -and
		 $this.FadeOrSlideToolTipsIntoView -ne [BinarySettingState]::KeepCurrentValue -and
		 $this.FadeOrSlideToolTipsIntoView -ne $this.currentState.FadeOrSlideToolTipsIntoView -and
		 $this.FadeOutMenuItemsAfterClicking -ne [BinarySettingState]::KeepCurrentValue -and
		 $this.FadeOutMenuItemsAfterClicking -ne $this.currentState.FadeOutMenuItemsAfterClicking -and
		 $this.ShowShadowsUnderWindows -ne [BinarySettingState]::KeepCurrentValue -and
		 $this.ShowShadowsUnderWindows -ne $this.currentState.ShowShadowsUnderWindows) {

			return $false
		}

		return $true
    }

    [void] Set() {
		if ($this.Test() -eq $false) {
            $SmoothScrollListBoxesDesiredValue = switch ([BinarySettingState]($this.SmoothScrollListBoxes)) {
                Enabled {1}
                Disabled {0}
            }

			$this.AnimationState = Get-AnimiationState -desiredValue $SmoothScrollListBoxesDesiredValue

			if (-not (Test-Path -Path $global:AnimationEffectsRegistryPath)) {
                New-Item -Path $global:AnimationEffectsRegistryPath -Force | Out-Null
			}

			Set-ItemProperty -Path $global:AnimationEffectsRegistryPath -Name $this.AnimationEffectsProperty -Value ($this.AnimationState | %{[convert]::ToInt32($_,2).ToString("X").PadLeft(2,'0')})
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

function Get-AnimiationState {
	param(
		[Parameter(Mandatory)]
		[int]$desiredValue,

		#Looking for a better way to handle this.
		[string] $AnimationEffectsProperty = 'UserPreferencesMask'
	)

	$AnimationState = (Get-ItemPropertyValue -Path $global:AnimationEffectsRegistryPath -Name $AnimationEffectsProperty) | %{[System.Convert]::ToString($_,2).PadLeft(8,'0')} 

	$AnimationState[0] = $AnimationState[0][0..3]+$desiredValue+$desiredValue+$desiredValue+$AnimationState[0][7] -join ""

	$AnimationState[1] = $AnimationState[1][0..1]+$desiredValue+$AnimationState[1][3]+$desiredValue+$desiredValue+$AnimationState[1][6..7] -join ""

	$AnimationState[2] = $AnimationState[2][0..4]+$desiredValue+$AnimationState[2][6..7] -join ""
	return $AnimationState
}

#endregion Functions