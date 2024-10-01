
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.Accessibility

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.Accessibility PowerShell module.
#>

BeforeAll {
    if ($null -eq (Get-Module -ListAvailable -Name PSDesiredStateConfiguration))
    {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }
	
    Import-Module Microsoft.Windows.Setting.Accessibility

    # Create test registry path.
    New-Item -Path TestRegistry:\ -Name TestKey
    # Set-ItemProperty requires the PSDrive to be in the format 'HKCU:'.
    $env:TestRegistryPath = ((Get-Item -Path TestRegistry:\).Name).replace("HKEY_CURRENT_USER", "HKCU:")
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "Text", "Magnifier", "MousePointer", "VisualEffect", "Audio", "TextCursor"
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Accessibility).Name
        $availableDSCResources.length | Should -Be 6
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'Text' {
    It 'Keeps current value.' {
        $initialState = Invoke-DscResource -Name Text -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}

        $parameters = @{ Size = 'KeepCurrentValue' }

        $testResult = Invoke-DscResource -Name Text -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $true

        # Invoking set should not change these values.
        Invoke-DscResource -Name Text -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name Text -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.Size | Should -Be $initialState.Size
    }

    It 'Sets desired value' {
        # Randomly generate desired state. Minimum is set to 1 to avoid KeepCurrentValue
        $desiredTextSize = [TextSize](Get-Random -Maximum 4 -Minimum 1)

        $desiredState = @{ Size = $desiredTextSize }
      
        Invoke-DscResource -Name Text -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $desiredState
   
        $finalState = Invoke-DscResource -Name Text -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.Size | Should -Be $desiredTextSize
    }
}

Describe 'Magnifier' {
    It 'Keeps current value.' {
        $initialState = Invoke-DscResource -Name Magnifier -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}

        $parameters = @{ Magnification = 'KeepCurrentValue' }

        $testResult = Invoke-DscResource -Name Magnifier -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $true

        # Invoking set should not change these values.
        Invoke-DscResource -Name Magnifier -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name Magnifier -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.Magnification | Should -Be $initialState.Magnification
    }

    It 'Sets desired value' {
        # Randomly generate desired state. Minimum is set to 1 to avoid KeepCurrentValue
        $desiredMagnification = [MagnificationValue](Get-Random -Maximum 4 -Minimum 1)

        $desiredState = @{ Magnification = $desiredMagnification }
      
        Invoke-DscResource -Name Magnifier -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $desiredState
   
        $finalState = Invoke-DscResource -Name Magnifier -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.Magnification | Should -Be $desiredMagnification
    }
}

Describe 'MousePointer' {
    It 'Keeps current value.' {
        $initialState = Invoke-DscResource -Name MousePointer -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}

        $parameters = @{ PointerSize = 'KeepCurrentValue' }

        $testResult = Invoke-DscResource -Name MousePointer -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $true

        # Invoking set should not change these values.
        Invoke-DscResource -Name MousePointer -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name MousePointer -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.PointerSize | Should -Be $initialState.PointerSize
    }

    It 'Sets desired value' {
        # Randomly generate desired state. Minimum is set to 1 to avoid KeepCurrentValue
        $desiredPointerSize = [PointerSize](Get-Random -Maximum 4 -Minimum 1)

        $desiredState = @{ PointerSize = $desiredPointerSize }
      
        Invoke-DscResource -Name MousePointer -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $desiredState
   
        $finalState = Invoke-DscResource -Name MousePointer -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.PointerSize | Should -Be $desiredPointerSize
    }
}

Describe 'VisualEffect'{
    It 'AlwaysShowScrollbars.'{
        Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{ AlwaysShowScrollbars = $false }

        $initialState = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $initialState.AlwaysShowScrollbars | Should -Be $false

        # Set 'AlwaysShowScrollbars' to true.
        $parameters = @{ AlwaysShowScrollbars = $true }
        $testResult = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $false

        # Verify the changes are correct.
        Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.AlwaysShowScrollbars | Should -Be $true

        $testResult2 = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult2.InDesiredState | Should -Be $true
    }
    It 'TransparencyEffects.'{
        Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{ TransparencyEffects = $false }

        $initialState = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $initialState.TransparencyEffects | Should -Be $false

        # Set 'TransparencyEffects' to true.
        $parameters = @{ TransparencyEffects = $true }
        $testResult = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $false

        # Verify the changes are correct.
        Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.TransparencyEffects | Should -Be $true

        $testResult2 = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult2.InDesiredState | Should -Be $true
    }
   It 'MessageDuration'{
        $firstValue = 5 #Key is missing by default, and default value is 5 when not specified. 
        $secondValue = 10
		
        $initialState = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $initialState.MessageDurationInSeconds | Should -Be $firstValue

        # Set 'MessageDurationInSeconds' to 10.
        $parameters = @{ MessageDurationInSeconds = $secondValue }
        $testResult = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $false

        # Verify the changes are correct.
        Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.MessageDurationInSeconds | Should -Be $secondValue

        $testResult2 = Invoke-DscResource -Name VisualEffect -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult2.InDesiredState | Should -Be $true
    }
}

Describe 'Audio'{
    It 'EnableMonoAudio.'{
        Invoke-DscResource -Name Audio -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{ EnableMonoAudio = $false }

        $initialState = Invoke-DscResource -Name Audio -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $initialState.EnableMonoAudio | Should -Be $false

        # Set 'EnableMonoAudio' to true.
        $parameters = @{ EnableMonoAudio = $true }
        $testResult = Invoke-DscResource -Name Audio -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $false

        # Verify the changes are correct.
        Invoke-DscResource -Name Audio -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name Audio -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.EnableMonoAudio | Should -Be $true

        $testResult2 = Invoke-DscResource -Name Audio -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult2.InDesiredState | Should -Be $true
    }
}

Describe 'TextCursor'{
    It 'TextCursorIndicatorStatus.'{
        $initialState = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $initialState.TextCursorIndicatorStatus # Should -Be $false

        # Set 'TextCursorIndicatorStatus' to true.
        $parameters = @{ TextCursorIndicatorStatus = $true }
        $testResult = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState # Should -Be $false

        # Verify the changes are correct.
        Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.TextCursorIndicatorStatus # Should -Be $true

        $testResult2 = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult2.InDesiredState # Should -Be $true
    }
    It 'TextCursorIndicatorSize.'{ 
        Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{ TextCursorIndicatorSize = 1 }

        $initialState = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $initialState.TextCursorIndicatorSize | Should -Be 1

        # Set 'TextCursorIndicatorSize' to 2.
        $parameters = @{ TextCursorIndicatorSize = 2 }
        $testResult = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $false

        # Verify the changes are correct.
        Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.TextCursorIndicatorSize | Should -Be 2

        $testResult2 = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult2.InDesiredState | Should -Be $true
    }
    It 'TextCursorIndicatorColor.'{ 
        Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property @{ TextCursorIndicatorColor = 16711871 }

        $initialState = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $initialState.TextCursorIndicatorColor | Should -Be 16711871

        # Set 'TextCursorIndicatorColor' to true.
        $parameters = @{ TextCursorIndicatorColor = 16711872 } #Increment default by 1
        $testResult = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $false

        # Verify the changes are correct.
        Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.TextCursorIndicatorColor | Should -Be 16711872

        $testResult2 = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult2.InDesiredState | Should -Be $true
    }
   It 'TextCursorThickness'{ #int
        $firstValue = 1 #Key is missing by default, and default value is 5 when not specified. 
        $secondValue = 2
		
        $initialState = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $initialState.TextCursorThickness | Should -Be $firstValue

        # Set 'TextCursorThickness' to 2.
        $parameters = @{ TextCursorThickness = $secondValue }
        $testResult = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $false

        # Verify the changes are correct.
        Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
        $finalState.TextCursorThickness | Should -Be $secondValue

        $testResult2 = Invoke-DscResource -Name TextCursor -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
        $testResult2.InDesiredState | Should -Be $true
    }
}

AfterAll {
    $env:TestRegistryPath = ""
}
