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

<##>
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
#>

<##>
#region DSCResources
[DSCResource()]	
class TextSize {
	[DscProperty(Key)]
	[ValidateSet('Small', 'Medium', 'Large', 'ExtraLarge')]
	[string] $TextSize

	### Registry Keys and Values
	hidden [string] $RegistryKey = "HKCU:\Software\Microsoft\Accessibility"
	hidden [string] $RegistryValue = "TextScaleFactor"

	### Use Switch to map the registry value to the enum value
	# hidden [TextSizeEnum] MapRegistryValueToEnum([int]$currentTextSizeValue) {
	# 	switch ($currentTextSizeValue) {
	# 		96 { return [TextSizeEnum]::Small }
	# 		120 { return [TextSizeEnum]::Medium }
	# 		144 { return [TextSizeEnum]::Large }
	# 		192 { return [TextSizeEnum]::ExtraLarge }
	# 		default { throw "Invalid registry value: $currentTextSizeValue" }
	# 	}
	# }

	[TextSize] Get() {
		### Get the current value from the registry
		if (Test-Path -Path $this.RegistryKey) {
			$currentTextSizeValue = Get-ItemProperty -Path $this.RegistryKey -Name $this.RegistryValue -ErrorAction SilentlyContinue `
			| Select-Object -ExpandProperty $this.RegistryValue
		}
		else {
			$currentTextSizeValue = $null
		}

		### Use switch to map the registry value to the enum value
		# switch ($currentTextSizeValue) {
		# 	96 { $currentTextSizeValue = 'Small' }
		# 	120 { $currentTextSizeValue = 'Medium' }
		# 	144 { $currentTextSizeValue = 'Large' }
		# 	192 { $currentTextSizeValue = 'ExtraLarge' }
		# 	default { $currentTextSizeValue = $null }
		# }
	
		return @{
			#CurrentTextSize = $this.MapRegistryValueToEnum($currentTextSizeValue)
			#TextSize = $this.MapRegistryValueToEnum($currentTextSizeValue)

			### Parse the enum value to an integer
			###  - The 'true' parameter is used to ignore case sensitivity
			TextSize = [TextSizeEnum]::Parse([TextSizeEnum], $this.TextSize, $true)
		}
	}

	[bool] Test() {
		$currentTestSizeValue = $this.Get()
		return $currentTestSizeValue.TextSize -eq $this.TextSize
	}

	[void] Set() {

		### Parse the enum value to an integer
		###  - The 'true' parameter is used to ignore case sensitivity
		$DesiredTextSizeValue = [int][TextSizeEnum]::Parse([TextSizeEnum], $this.TextSize, $true)

		if (-not $(Test-Path -Path $this.RegistryKey)) {
			try {
				New-Item -Path $this.RegistryKey -Force
			}
			catch {
				throw $_.Exception.Message
			}
		}
        
		try {
			Set-ItemProperty -Path $this.RegistryKey -Name $this.RegistryValue -Value $DesiredTextSizeValue
		}
		catch {
			throw $_.Exception.Message
		}

		### Refresh the New Settings
		#Get-Process -Name explorer | Stop-Process -Force -ErrorAction SilentlyContinue
	}
}
#>

<##>
[DSCResource()]	
class MousePointerSize {
	[DscProperty(Key)]
	[ValidateSet('Small', 'Medium', 'Large', 'ExtraLarge')]
	[string] $MousePointerSize

	hidden [string] $RegistryKey = "HKCU:\Software\Microsoft\Accessibility"
	hidden [string] $RegistryValue = "TextScaleFactor"

	[MousePointerSize] Get() {
		### Get the current value from the registry
		if (Test-Path -Path $this.RegistryKey) {
			$currentSizeValue = Get-ItemProperty -Path $this.RegistryKey -Name $this.RegistryValue -ErrorAction SilentlyContinue `
			| Select-Object -ExpandProperty $this.RegistryValue
		}
		else {
			$currentSizeValue = $null
		}
		return @{
			MousePointerSize = [MousePointerSizeEnum]::GetName([MousePointerSizeEnum], $currentSizeValue)
			#MousePointerSize = [MousePointerSizeEnum]::Parse([MousePointerSizeEnum], $this.MousePointerSize, $true)
		}
	}

	[bool] Test() {
		$currentSizeName = $this.Get()
		return $currentSizeName.MousePointerSize -eq $this.MousePointerSize
	}

	[void] Set() {

		### Parse the enum value to an integer
		###  - The 'true' parameter is used to ignore case sensitivity
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

		### Call Update-Reistry function
		Update-Registry

		# 			$CSharpSig = @'
		# [DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
		# public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
		# '@
		# 			$CursorRefresh = Add-Type -MemberDefinition $CSharpSig -Name WinAPICall -Namespace SystemParamInfo -PassThru
		# 			$CursorRefresh::SystemParametersInfo(0x2029, 0, $sizeValue, 0x01)  # Set a cursor size of 16 (you can adjust the value as needed)
		
	}
}
#>

<##>
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

			# Map the registry value to a valid 'Active' value
			$activeStateMap = @{
				0 = 'Inactive'
				1 = 'Active'
			}
			$currentActiveState = $activeStateMap[$registryActiveStateValue]

			# Map the registry value to a valid 'FilterType' value
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
		### Get the current values from the registry
		$currentState = $this.Get()
		$currentActiveState = $currentState.ActiveState
		$currentFilterType = $currentState.FilterType

		### Get the Desired values
		$desiredActiveState = $this.ActiveState
		$desiredFilterType = $this.FilterType

		### Test the values
		return ($currentActiveState -eq $desiredActiveState) -AND ($currentFilterType -eq $desiredFilterType)
	}

	[void] Set() {
		### Map the 'ActiveState' value to a valid registry value: 
		###   - "OrdinalIgnoreCase" is used to ignore case sensitivity
		$desiredActiveState = [int][ColorFilterActiveEnum]::Parse([ColorFilterActiveEnum], $this.ActiveState, [System.StringComparison]::OrdinalIgnoreCase)
		$desiredFilterType = [int][ColorFilterTypeEnum]::Parse([ColorFilterTypeEnum], $this.FilterType, [System.StringComparison]::OrdinalIgnoreCase)

		if (-not $(Test-Path -Path $this.RegistryKey)) {
			try {
				New-Item -Path $this.RegistryKey -Force
			}
			catch {
				throw $_.Exception.Message
			}
		}
		try {
			Set-ItemProperty -Path $this.RegistryKey -Name $this.RegistryActiveState -Value $desiredActiveState
			Set-ItemProperty -Path $this.RegistryKey -Name $this.RegistryFilterType -Value $desiredFilterType
		}
		catch {
			throw "Error setting registry values: $_"
		}

		### Refresh the registry
		#Get-Process -Name explorer | Stop-Process -Force -ErrorAction SilentlyContinue
		Invoke-ExplorerRefresh
	}
}
#>

<##>
# ### 3 Set: Text Cursor Settings
# ### -------------------------------------
# - resource: Microsoft.Windows.Developer/TextCursorSettings
#   directives:
#     description: Set text cursor settings
#     allowPrerelease: true
#   settings:
#     Width: 3 # Set the width of the text cursor
#     Color: "#FF0000" # Set the color of the text cursor
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
		### Get Cursor Enabled:
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

		### Get Cursor Size:
		if (Test-Path -Path $this.RegistryKeyCursorIndicator) {
			$currentIndicatorSizeValue = Get-ItemProperty -Path $this.RegistryKeyCursorIndicator -Name $this.RegistryValueIndicatorSize -ErrorAction SilentlyContinue `
			| Select-Object -ExpandProperty $this.RegistryValueIndicatorSize
		}
		else {
			$currentIndicatorSizeValue = $null
		}

		### Get Color Value:
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
		### Get the current values from the registry
		$currentState = $this.Get()
		$currentCursorIndicatorSize = $currentState.CursorIndicatorSize
		$currentCursorIndicatorColor = $currentState.CursorIndicatorSize

		### Get the Desired values
		$desiredCursorIndicatorSize = $this.CursorIndicatorSize
		$desiredCursorIndicatorColor = $this.CursorIndicatorSize

		### Test the values
		return ($currentCursorIndicatorSize -eq $desiredCursorIndicatorSize) -AND ($currentCursorIndicatorColor -eq $desiredCursorIndicatorColor)
	}

	[void] Set() {

		$desiredCursorIndicatorEnabled = [int][CursorIndicatorEnabledEnum]::Parse([CursorIndicatorEnabledEnum], $this.CursorIndicatorEnabled, [System.StringComparison]::OrdinalIgnoreCase)

		### Check if the cursor indicator is enabled, if not, enable it
		if (-not $(Test-Path -Path $this.RegistryKeyCursorIndicatorEnabled)) {
			New-Item -Path $this.RegistryKeyCursorIndicatorEnabled -Force
		}
		try {
			Set-ItemProperty -Path $this.RegistryKeyCursorIndicatorEnabled -Name 'Configuration' -Value 'cursorindicator'
		}
		catch {
			throw $_.Exception.Message
		}
		
		### Parse the enum value to an integer
		$desiredIndicatorSizeValue = [int][CursorIndicatorSizeEnum]::Parse([CursorIndicatorSizeEnum], $this.CursorIndicatorSize, $true)
		$desiredIndicatorColorValue = [int][CursorIndicatorColorEnum]::Parse([CursorIndicatorColorEnum], $this.CursorIndicatorColor, $true)
		#throw $desiredIndicatorColorValue

		if (-not $(Test-Path -Path $this.RegistryKeyCursorIndicator)) {
			New-Item -Path $this.RegistryKeyCursorIndicator -Force
		}

		try {
			Set-ItemProperty -Path $this.RegistryKeyCursorIndicator -Name $this.RegistryValueIndicatorSize -Value $desiredIndicatorSizeValue
			Set-ItemProperty -Path $this.RegistryKeyCursorIndicator -Name $this.RegistryValueIndicatorColor -Value $desiredIndicatorColorValue 
			Get-Process -Name explorer | Stop-Process -Force -ErrorAction SilentlyContinue
		}
		catch {
			throw $_.Exception.Message
		}
	}
}

<#
# ### 6 Set: High Contrast Settings
# ### -------------------------------------
# - resource: Microsoft.Windows.Developer/HighContrastSettings
#   directives:
#     description: Set High Contrast settings
#     allowPrerelease: true
#   settings:
#     Theme: "High Contrast #1" # Set the High Contrast theme
#     Enable: true # Enable or disable High Contrast
# HKEY_CURRENT_USER\Control Panel\Colors
# HKEY_CURRENT_USER\Control Panel\Desktop\Colors2
enum HighContrastSettingsEnum{
	HighContrast1 = 1
	HighContrast2 = 2
	HighContrast3 = 3
	HighContrast4 = 4
	HighContrast5 = 5
	HighContrast6 = 6
	HighContrast7 = 7
	HighContrast8 = 8
	HighContrast9 = 9
	HighContrast10 = 10
}
[DSCResource()]	
class HighContrastSettings {
	[DscProperty(Key)]
	[string] $Size

	[DscProperty(Mandatory)]
	[string] $Value

	[DscProperty(Mandatory)]
	[string] $Ensure

	[HighContrastSettings] Get() {
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
#>



#endregion DSCResources

#region Functions
<#
function Invoke-ExplorerRefresh {
	if (-not ([System.Management.Automation.PSTypeName]'RefreshExplorer').Type) {
		$code = @"
using System;
{
    private static readonly IntPtr HWND_BROADCAST = new IntPtr(0xffff);
    private const uint WM_SETTINGCHANGE = (uint)0x1a;
    private const uint SHCNE_ASSOCCHANGED = (uint)0x08000000L;
    private const uint SHCNF_FLUSH = (uint)0x1000;

    [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, IntPtr lpdwResult);

    [System.Runtime.InteropServices.DllImport("Shell32.dll")]
    private static extern int SHChangeNotify(uint eventId, uint flags, IntPtr item1, IntPtr item2);

    public static void Refresh() {
        SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_FLUSH, IntPtr.Zero, IntPtr.Zero);
    }
}
"@
	}
	try {
		Add-Type -TypeDefinition $code -Language CSharp
	}
	catch {
		Write-Host "Error adding type: $_"
		if ($_.Exception -is [System.Management.Automation.ParseException]) {
			$_.Exception.Errors | ForEach-Object {
				Write-Host ("Line {0}: {1}" -f $_.Line, $_.Message)
			}
		}

		try {
			[RefreshExplorer]::Refresh()
		}
		catch {
			Write-Host "Error calling Refresh: $_"
		}
	}
}
#>

<#
function Update-Registry {
	### Refresh the registry
	$CSharpSig = @'
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
'@
	$CursorRefresh = Add-Type -MemberDefinition $CSharpSig -Name WinAPICall -Namespace SystemParamInfo -PassThru
	$CursorRefresh::SystemParametersInfo(0x2029, 0, $sizeValue, 0x01)  # Set a cursor size of 16 (you can adjust the value as needed)
}
#>


#endregion Functions


#region Tests

### Text Size
###-------------------------------------
# Invoke-DscResource -Name TextSize -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{TextSize = 'Medium' }
# Invoke-DscResource -Name TextSize -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property @{TextSize = 'Small' }
# Invoke-DscResource -Name TextSize -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{TextSize = "Small" }

### Mouse Pointer Size
###-------------------------------------
# Invoke-DscResource -Name MousePointerSize -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{MousePointerSize = 'Medium' }
# Invoke-DscResource -Name MousePointerSize -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property @{MousePointerSize = 'Medium' }
# Invoke-DscResource -Name MousePointerSize -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{MousePointerSize = 'Medium' }

### Color Filter Settings
###-------------------------------------
# Invoke-DscResource -Name ColorFilterSettings -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{ActiveState = 'inActive'; FilterType = 'Grayscale' }
# Invoke-DscResource -Name ColorFilterSettings -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property @{ActiveState = 'inActive'; FilterType = 'Grayscale' }
# Invoke-DscResource -Name ColorFilterSettings -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{ActiveState = 'inActive'; FilterType = 'Grayscale' }

### Cursor Settings
###-------------------------------------
# Invoke-DscResource -Name CursorIndicatorSettings -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{CursorIndicatorEnabled = 'On'; CursorIndicatorSize = 'Small'; CursorIndicatorColor = 'Purple' }
# Invoke-DscResource -Name CursorIndicatorSettings -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property @{CursorIndicatorEnabled = 'On'; CursorIndicatorSize = 'Small'; CursorIndicatorColor = 'Purple' }
# Invoke-DscResource -Name CursorIndicatorSettings -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{CursorIndicatorEnabled = 'On'; CursorIndicatorSize = 'Small'; CursorIndicatorColor = 'Purple' }

#endregion Tests

### Module Import
###-------------------------------------
#Get-ChildItem -File  | Unblock-File

# Get-DscResource -Module Microsoft.Windows.Setting.Accessibility


#$path = "C:\Repo\winget-dsc-CBrennan\resources\Microsoft.Windows.Developer"
# $path = "C:\Repo\winget-dsc-CBrennan\resources"
# $env:PSModulePath = $path + ";" + $env:PSModulePath
#$env:PSModulePath.Split(";")
#Import-Module -Name 'Microsoft.Windows.Setting.Accessibility'-Force
#Get-module -ListAvailable | Where-Object { $_.Name -eq 'Microsoft.Windows.Setting.Accessibility' } 
#Get-DscResource -Module Microsoft.Windows.Setting.Accessibility