# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#region enums
enum Ensure {
	Absent
	Present
}

enum TextSizeEnum {
	Small = 96
	Medium = 120
	Large = 144
	ExtraLarge = 192
}

enum MousePointerSizeEnum {
	Small = 32	
	Medium = 96
	Large = 144
	ExtraLarge = 256
}

enum AlignmentEnum{
	KeepCurrentValue
	Left
	Middle
}

enum ColorFilterActiveEnum {
	Active = 1
	Inactive = 0
}

enum ColorFilterTypeEnum {
	Grayscale = 0
	Inverted = 1
	GrayscaleInverted = 2
	RedGreen = 3
	GreenRed = 4
	BlueYellow = 5
}

enum CursorIndicatorEnabledEnum {
	On = 1
	Off = 0
}
enum CursorIndicatorSizeEnum {
	VerySmall = 1
	Small = 2
	Medium = 3
	Large = 4
	ExtraLarge = 5
}

enum CursorIndicatorColorEnum {
	Purple = 16711871
	Lime = 65471
	Yellow = 64250
	Gold = 49151
	Pink = 12517631
	Turquoise = 16760576
	Green = 12582656
}
#endregion enums

[DSCResource()]
class Template {
	[DscProperty(Key)]
	[string] $Size

	[DscProperty(Mandatory)]
	[string] $Value

	[DscProperty(Mandatory)]
	[string] $Ensure

	[Template] Get() {
		return @{
			Size = "Small"
		}
	}
	
	[bool] Test() {
		return $false
	}

	[void] Set() {
	}
}

#region DSCResources
[DSCResource()]	
class TextSize {
	[DscProperty(Key)]
	[ValidateSet('Small', 'Medium', 'Large', 'ExtraLarge')]
	[string] $TextSize

	hidden [string] $RegistryKey = "HKCU:\Software\Microsoft\Accessibility"
	hidden [string] $RegistryValue = "TextScaleFactor"

	[TextSize] Get() {
		if (Test-Path -Path $this.RegistryKey) {
			$currentTextSizeValue = Get-ItemProperty -Path $this.RegistryKey -Name $this.RegistryValue -ErrorAction SilentlyContinue `
			| Select-Object -ExpandProperty $this.RegistryValue
		}
		else {
			$currentTextSizeValue = $null
		}

		return @{
			TextSize = [TextSizeEnum]::Parse([TextSizeEnum], $this.TextSize, $true)
		}
	}

	[bool] Test() {
		$currentTestSizeValue = $this.Get()
		return $currentTestSizeValue.TextSize -eq $this.TextSize
	}

	[void] Set() {
		$DesiredTextSizeValue = [int][TextSizeEnum]::Parse([TextSizeEnum], $this.TextSize, $true)
		try {
			if (-not $(Test-Path -Path $this.RegistryKey)) {
				New-Item -Path $this.RegistryKey -Force
			}
			Set-ItemProperty -Path $this.RegistryKey -Name $this.RegistryValue -Value $DesiredTextSizeValue
		}
		catch {
			throw $_.Exception.Message
		}
		Get-Process -Name explorer | Stop-Process -Force -ErrorAction SilentlyContinue
	}
}

[DSCResource()]	
class MousePointerSize {
	[DscProperty(Key)]
	[ValidateSet('Small', 'Medium', 'Large', 'ExtraLarge')]
	[string] $MousePointerSize

	hidden [string] $RegistryKey = "HKCU:\Software\Microsoft\Accessibility"
	hidden [string] $RegistryValue = "TextScaleFactor"

	[MousePointerSize] Get() {
		if (Test-Path -Path $this.RegistryKey) {
			$currentSizeValue = Get-ItemProperty -Path $this.RegistryKey -Name $this.RegistryValue -ErrorAction SilentlyContinue `
			| Select-Object -ExpandProperty $this.RegistryValue
		}
		else {
			$currentSizeValue = $null
		}
		return @{
			MousePointerSize = [MousePointerSizeEnum]::GetName([MousePointerSizeEnum], $currentSizeValue)
		}
	}

	[bool] Test() {
		$currentValue = $this.Get()
		$desiredValue = $this.MousePointerSize

		return $currentValue.MousePointerSize -eq $desiredValue
	}

	[void] Set() {
		$sizeValue = [int][MousePointerSizeEnum]::Parse([MousePointerSizeEnum], $this.MousePointerSize, $true)

		if (-not $(Test-Path -Path $this.RegistryKey)) {
			New-Item -Path $this.RegistryKey -Force
		}

		try {
			Set-ItemProperty -Path $this.RegistryKey -Name $this.RegistryValue -Value $sizeValue
		}
		catch {
			throw $_.Exception.Message
		}
	}
}

[DSCResource()]	
class ColorFilterSettings {
	[DscProperty(Key)]
	[ValidateSet('Active', 'Inactive')]
	[string] $ActiveState

	[DscProperty()]
	[ValidateSet('Grayscale', 'Inverted', 'GrayscaleInverted', 'RedGreen', 'GreenRed', 'BlueYellow')]
	[string] $FilterType

	hidden [string] $RegistryKey = "HKCU:\Software\Microsoft\ColorFiltering"
	hidden [string] $RegistryActiveState = "Active"
	hidden [string] $RegistryFilterType = "FilterType"

	[ColorFilterSettings] Get() {
		if (Test-Path -Path $this.RegistryKey) {
			try {
				$registryActiveStateValue = Get-ItemProperty -Path $this.RegistryKey -Name $this.RegistryActiveState -ErrorAction SilentlyContinue `
				| Select-Object -ExpandProperty $this.RegistryActiveState

				$registryFilterTypeValue = Get-ItemProperty -Path $this.RegistryKey -Name $this.RegistryFilterType -ErrorAction SilentlyContinue `
				| Select-Object -ExpandProperty $this.RegistryFilterType
			}
			catch {
				throw "Error getting registry values: $_"
			}

			$activeStateMap = @{
				0 = 'Inactive'
				1 = 'Active'
			}
			$currentActiveState = $activeStateMap[$registryActiveStateValue]

			$filterTypeMap = @{
				0 = 'Grayscale'
				1 = 'Inverted'
				2 = 'GrayscaleInverted'
				3 = 'RedGreen'
				4 = 'GreenRed'
				5 = 'BlueYellow'
			}
			$currentFilterTypeName = $filterTypeMap[$registryFilterTypeValue]

			return @{
				ActiveState = $currentActiveState
				FilterType  = $currentFilterTypeName
			}
		}
		else {
			return @{
				ActiveState = $null
				FilterType  = $null
			}
		}
	}

	[bool] Test() {
		$currentState = $this.Get()
		$currentActiveState = $currentState.ActiveState
		$currentFilterType = $currentState.FilterType

		$desiredActiveState = $this.ActiveState
		$desiredFilterType = $this.FilterType

		return ($currentActiveState -eq $desiredActiveState) -AND ($currentFilterType -eq $desiredFilterType)
	}

	[void] Set() {
		$desiredActiveState = [int][ColorFilterActiveEnum]::Parse([ColorFilterActiveEnum], $this.ActiveState, [System.StringComparison]::OrdinalIgnoreCase)
		$desiredFilterType = [int][ColorFilterTypeEnum]::Parse([ColorFilterTypeEnum], $this.FilterType, [System.StringComparison]::OrdinalIgnoreCase)

		try {
			if (-not $(Test-Path -Path $this.RegistryKey)) {
				New-Item -Path $this.RegistryKey -Force
			}
			Set-ItemProperty -Path $this.RegistryKey -Name $this.RegistryActiveState -Value $desiredActiveState
			Set-ItemProperty -Path $this.RegistryKey -Name $this.RegistryFilterType -Value $desiredFilterType
		}
		catch {
			throw $_.Exception.Message
		}
	}
}

[DSCResource()]	
class CursorIndicatorSettings {
	[DscProperty(Key)]
	[ValidateSet('On', 'Off')]
	[string] $CursorIndicatorEnabled

	[DscProperty(Mandatory = $false)]
	[ValidateSet('VerySmall', 'Small', 'Medium', 'Large', 'ExtraLarge')]
	[string] $CursorIndicatorSize

	[DscProperty(Mandatory = $false)]
	[ValidateSet('Purple', 'Lime', 'Yellow', 'Gold', 'Pink', 'Turquoise', 'Green')]
	[string] $CursorIndicatorColor

	hidden [string] $RegistryKeyCursorIndicatorEnabled = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility"
	hidden [string] $RegistryKeyCursorIndicator = "HKCU:\Software\Microsoft\Accessibility\CursorIndicator"
	hidden [string] $RegistryValueIndicatorSize = "IndicatorType"
	hidden [string] $RegistryValueIndicatorColor = "IndicatorColor"

	[CursorIndicatorSettings] Get() {
		if (Test-Path -Path $this.RegistryKeyCursorIndicatorEnabled) {
			$currentCursorIndicatorEnabled = Get-ItemProperty -Path $this.RegistryKeyCursorIndicatorEnabled -Name "Configuration" -ErrorAction SilentlyContinue `
			| Select-Object -ExpandProperty "Configuration"
			
			if ($currentCursorIndicatorEnabled -eq "cursorindicator") {
				$currentCursorIndicatorEnabled = "On"
			}
			else {
				$currentCursorIndicatorEnabled = "Off"
			}
		}
		else {
			$currentCursorIndicatorEnabled = $null
		}

		if (Test-Path -Path $this.RegistryKeyCursorIndicator) {
			$currentIndicatorSizeValue = Get-ItemProperty -Path $this.RegistryKeyCursorIndicator -Name $this.RegistryValueIndicatorSize -ErrorAction SilentlyContinue `
			| Select-Object -ExpandProperty $this.RegistryValueIndicatorSize
		}
		else {
			$currentIndicatorSizeValue = $null
		}

		if (Test-Path -Path $this.RegistryKeyCursorIndicator) {
			$currentIndicatorColorValue = Get-ItemProperty -Path $this.RegistryKeyCursorIndicator -Name $this.RegistryValueIndicatorColor -ErrorAction SilentlyContinue `
			| Select-Object -ExpandProperty $this.RegistryValueIndicatorColor
		}
		else {
			$currentIndicatorColorValue = $null
		}

		return @{
			CursorIndicatorEnabled = $currentCursorIndicatorEnabled
			CursorIndicatorSize    = [CursorIndicatorSizeEnum]::Parse([CursorIndicatorSizeEnum], $currentIndicatorSizeValue, $true)
			CursorIndicatorColor   = [CursorIndicatorColorEnum]::Parse([CursorIndicatorColorEnum], $currentIndicatorColorValue, $true)
		}
	}

	[bool] Test() {
		$currentState = $this.Get()
		$currentCursorIndicatorSize = $currentState.CursorIndicatorSize
		$currentCursorIndicatorColor = $currentState.CursorIndicatorSize

		$desiredCursorIndicatorSize = $this.CursorIndicatorSize
		$desiredCursorIndicatorColor = $this.CursorIndicatorSize

		return ($currentCursorIndicatorSize -eq $desiredCursorIndicatorSize) -AND ($currentCursorIndicatorColor -eq $desiredCursorIndicatorColor)
	}

	[void] Set() {

		$desiredCursorIndicatorEnabled = [int][CursorIndicatorEnabledEnum]::Parse([CursorIndicatorEnabledEnum], $this.CursorIndicatorEnabled, [System.StringComparison]::OrdinalIgnoreCase)
		try {
			if (-not $(Test-Path -Path $this.RegistryKeyCursorIndicatorEnabled)) {
				New-Item -Path $this.RegistryKeyCursorIndicatorEnabled -Force
			}
			Set-ItemProperty -Path $this.RegistryKeyCursorIndicatorEnabled -Name 'Configuration' -Value 'cursorindicator'
		}
		catch {
			throw $_.Exception.Message
		}
		
		$desiredIndicatorSizeValue = [int][CursorIndicatorSizeEnum]::Parse([CursorIndicatorSizeEnum], $this.CursorIndicatorSize, $true)
		$desiredIndicatorColorValue = [int][CursorIndicatorColorEnum]::Parse([CursorIndicatorColorEnum], $this.CursorIndicatorColor, $true)

		try {
			if (-not $(Test-Path -Path $this.RegistryKeyCursorIndicator)) {
				New-Item -Path $this.RegistryKeyCursorIndicator -Force
			}
			Set-ItemProperty -Path $this.RegistryKeyCursorIndicator -Name $this.RegistryValueIndicatorSize -Value $desiredIndicatorSizeValue
			Set-ItemProperty -Path $this.RegistryKeyCursorIndicator -Name $this.RegistryValueIndicatorColor -Value $desiredIndicatorColorValue 
			Get-Process -Name explorer | Stop-Process -Force -ErrorAction SilentlyContinue
		} 
		catch {
			throw $_.Exception.Message
		}
	}
}
