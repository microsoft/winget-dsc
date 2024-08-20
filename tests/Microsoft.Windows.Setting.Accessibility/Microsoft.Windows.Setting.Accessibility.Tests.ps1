
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
    Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    Import-Module Microsoft.Windows.Setting.Accessibility

    # Create test registry path.
    New-Item -Path TestRegistry:\ -Name TestKey
    # Set-ItemProperty requires the PSDrive to be in the format 'HKCU:'.
    $env:TestRegistryPath = ((Get-Item -Path TestRegistry:\).Name).replace("HKEY_CURRENT_USER", "HKCU:")
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "Text", "Magnifier", "MousePointer"
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Accessibility).Name
        $availableDSCResources.length | Should -Be 3
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

Describe 'DynamicScrollbars'{
   It 'Keeps current value.'{
      $initialState = Invoke-DscResource -Name AlwaysShowScrollbars -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}

      $parameters = @{ ShowScrollBars = 'KeepCurrentValue' }

      $testResult = Invoke-DscResource -Name AlwaysShowScrollbars -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true

      # Invoking set should not change these values.
      Invoke-DscResource -Name AlwaysShowScrollbars -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
      $finalState = Invoke-DscResource -Name AlwaysShowScrollbars -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
      $finalState.ShowScrollBars | Should -Be $initialState.ShowScrollBars
   }

   It 'Sets desired value.'{
      # Randomly generate desired state. Minimum is set to 1 to avoid using KeepCurrentValue
      $desiredScrollbarBehavior = [ShowScrollBars](Get-Random -Maximum 2 -Minimum 1)

      $desiredState = @{ ShowScrollBars = $desiredScrollbarBehavior }

      Invoke-DscResource -Name AlwaysShowScrollbars -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name AlwaysShowScrollbars -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
      $finalState.ShowScrollBars | Should -Be $desiredScrollbarBehavior
	  
   }
}

AfterAll {
    $env:TestRegistryPath = ""
}