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

enum AnimationEffectsSettings {
    SmoothScrollListBoxes
	SlideOpenComboBoxes
	FadeOrSlideMenusIntoView
	ShowShadowsUnderMousePointer
	FadeOrSlideToolTipsIntoView
	FadeOutMenuItemsAfterClicking
	ShowShadowsUnderWindows
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

		$this.currentState = [BinarySettingState]::Disabled

		foreach ($enum in [AnimationEffectsSettings].GetEnumNames()) {
			$thisState = Get-AnimationState $enum
			if ($thisState -eq [BinarySettingState]::Enabled) {
				$this.currentState = [BinarySettingState]::Enabled
			}
		}

		return $this.currentState
	}

    [bool] Test() {
 		$this.currentState = $this.Get()
		if ($this.SmoothScrollListBoxes -ne [BinarySettingState]::KeepCurrentValue -or
		$this.SmoothScrollListBoxes -ne $this.currentState.SmoothScrollListBoxes) {

			return $false
		}
		
		elseif ($this.SlideOpenComboBoxes -ne [BinarySettingState]::KeepCurrentValue -or
		$this.SlideOpenComboBoxes -ne $this.currentState.SlideOpenComboBoxes) {

			return $false
		}
		
		elseif ($this.FadeOrSlideMenusIntoView -ne [BinarySettingState]::KeepCurrentValue -or
		$this.FadeOrSlideMenusIntoView -ne $this.currentState.FadeOrSlideMenusIntoView) {

			return $false
		}
		
		elseif ($this.ShowShadowsUnderMousePointer -ne [BinarySettingState]::KeepCurrentValue -or
		$this.ShowShadowsUnderMousePointer -ne $this.currentState.ShowShadowsUnderMousePointer) {

			return $false
		}
		
		elseif ($this.ShowShadowsUnderMousePointer -ne [BinarySettingState]::KeepCurrentValue -or
		$this.ShowShadowsUnderMousePointer -ne $this.currentState.ShowShadowsUnderMousePointer) {

			return $false
		}
		
		elseif ($this.FadeOrSlideToolTipsIntoView -ne [BinarySettingState]::KeepCurrentValue -or
		$this.FadeOrSlideToolTipsIntoView -ne $this.currentState.FadeOrSlideToolTipsIntoView) {

			return $false
		}
		
		elseif ($this.FadeOutMenuItemsAfterClicking -ne [BinarySettingState]::KeepCurrentValue -or
		$this.FadeOutMenuItemsAfterClicking -ne $this.currentState.FadeOutMenuItemsAfterClicking) {

			return $false
		}
		
		elseif ($this.ShowShadowsUnderWindows -ne [BinarySettingState]::KeepCurrentValue -or
		$this.ShowShadowsUnderWindows -ne $this.currentState.ShowShadowsUnderWindows) {

			return $false
		}else {

		return $true
		}
    }

    [void] Set() {
		if ($this.Test() -eq $false) {

			$this.currentState = GetAnimationEffectsStateHexValue # -SmoothScrollListBoxesDesiredValue $SmoothScrollListBoxes
			# -SlideOpenComboBoxesDesiredValue $SlideOpenComboBoxes `
			# -FadeOrSlideMenusIntoViewDesiredValue $FadeOrSlideMenusIntoView `
			# -ShowShadowsUnderMousePointerDesiredValue $ShowShadowsUnderMousePointer `
			# -FadeOrSlideToolTipsIntoViewDesiredValue $FadeOrSlideToolTipsIntoView `
			# -FadeOutMenuItemsAfterClickingDesiredValue $FadeOutMenuItemsAfterClicking `
			# -ShowShadowsUnderWindowsDesiredValue $ShowShadowsUnderWindows

			if (-not (Test-Path -Path $global:AnimationEffectsRegistryPath)) {
                New-Item -Path $global:AnimationEffectsRegistryPath -Force | Out-Null
			}

			Set-ItemProperty -Path $global:AnimationEffectsRegistryPath -Name $this.AnimationEffectsProperty -Value $this.currentState
		}
	}
}

#region Functions
[string] $AnimationEffectsProperty = 'UserPreferencesMask'

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

function GetAnimationEffectsStateHexValue {
	param(
		[Parameter(Mandatory)]
		[BinarySettingState]$SmoothScrollListBoxesDesiredValue,

		[Parameter(Mandatory)]
		[BinarySettingState]$SlideOpenComboBoxesDesiredValue,

		[Parameter(Mandatory)]
		[BinarySettingState]$FadeOrSlideMenusIntoViewDesiredValue,

		[Parameter(Mandatory)]
		[BinarySettingState]$ShowShadowsUnderMousePointerDesiredValue,

		[Parameter(Mandatory)]
		[BinarySettingState]$FadeOrSlideToolTipsIntoViewDesiredValue,

		[Parameter(Mandatory)]
		[BinarySettingState]$FadeOutMenuItemsAfterClickingDesiredValue,

		[Parameter(Mandatory)]
		[BinarySettingState]$ShowShadowsUnderWindowsDesiredValue
	)

	[array]$OverallState = (Get-ItemPropertyValue -Path $global:AnimationEffectsRegistryPath -Name $AnimationEffectsProperty) | %{[System.Convert]::ToString($_,2).PadLeft(8,'0')}#Registry converts from hex to int, so this converts from int to binary.


		foreach ($enum in [AnimationEffectsSettings].GetEnumNames()) {
			$StateValue = switch ([AnimationEffectsSettings]$enum) {
				SmoothScrollListBoxes {$OverallState[0][4]}
				SlideOpenComboBoxes {$OverallState[0][5]}
				FadeOrSlideMenusIntoView {$OverallState[0][6]}
				ShowShadowsUnderMousePointer {$OverallState[1][2]}
				FadeOrSlideToolTipsIntoView {$OverallState[1][4]}
				FadeOutMenuItemsAfterClicking {$OverallState[1][5]}
				ShowShadowsUnderWindows {$OverallState[2][5]}
			}
			if ($StateValue -eq 1) {
				$OutputValue = [BinarySettingState]::Enabled
			}else {
				$OutputValue = [BinarySettingState]::Disabled
			}
			switch ([AnimationEffectsSettings]$enum) {
				SmoothScrollListBoxes {$SmoothScrollListBoxesDesiredValue = $OutputValue}
				SlideOpenComboBoxes {$SlideOpenComboBoxesDesiredValue = $OutputValue}
				FadeOrSlideMenusIntoView {$FadeOrSlideMenusIntoViewDesiredValue = $OutputValue}
				ShowShadowsUnderMousePointer {$ShowShadowsUnderMousePointerDesiredValue = $OutputValue}
				FadeOrSlideToolTipsIntoView {$FadeOrSlideToolTipsIntoViewDesiredValue = $OutputValue}
				FadeOutMenuItemsAfterClicking {$FadeOutMenuItemsAfterClickingDesiredValue = $OutputValue}
				ShowShadowsUnderWindows {$ShowShadowsUnderWindowsDesiredValue = $OutputValue}
			}
		}
		
		
	$OverallState = $OverallState | %{[convert]::ToInt32($_,2).ToString("X").PadLeft(2,'0')}#Converts from binary back to hex.
	return $OverallState
}


Function Get-AnimationState {
	param(
		[Parameter(Mandatory)]
		[AnimationEffectsSettings]$enum
	)
	
		$OverallState = (Get-ItemPropertyValue -Path $global:AnimationEffectsRegistryPath -Name $AnimationEffectsProperty) | %{[System.Convert]::ToString($_,2).PadLeft(8,'0')}#Registry converts from hex to int, so this converts from int to binary.
		
		$IndividualState = switch ([AnimationEffectsSettings]$enum) {
			SmoothScrollListBoxes {$OverallState[0][4]}
			SlideOpenComboBoxes {$OverallState[0][5]}
			FadeOrSlideMenusIntoView {$OverallState[0][6]}
			ShowShadowsUnderMousePointer {$OverallState[1][2]}
			FadeOrSlideToolTipsIntoView {$OverallState[1][4]}
			FadeOutMenuItemsAfterClicking {$OverallState[1][5]}
			ShowShadowsUnderWindows {$OverallState[2][5]}
		}

		if ($IndividualState -eq [BinarySettingState]::Disabled) {
			$currentState = [BinarySettingState]::Disabled
		}else {
			$currentState = [BinarySettingState]::Enabled
		}
	
	return $currentState
}
#endregion Functions