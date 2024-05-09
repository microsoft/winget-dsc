# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
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

enum CursorSize {
	KeepCurrentValue
	Small
	Medium
	Large
	ExtraLarge
}

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
	$global:AccessibilityRegistryPath = 'HKCU:\Software\Microsoft\Accessibility\'
}
else {
	$global:AccessibilityRegistryPath = $env:TestRegistryPath
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