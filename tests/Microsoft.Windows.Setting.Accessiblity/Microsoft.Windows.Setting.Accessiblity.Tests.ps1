# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.Accessibility
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
<#
.Synopsis
   Pester tests related to the Microsoft.WinGet.Developer PowerShell module.
#>
BeforeAll {
   Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
   Import-Module Microsoft.Windows.Accessibility
   # Create test registry path.
   New-Item -Path TestRegistry:\ -Name TestKey
   # Set-ItemProperty requires the PSDrive to be in the format 'HKCU:'.
   $env:TestRegistryPath = ((Get-Item -Path TestRegistry:\).Name).replace("HKEY_CURRENT_USER", "HKCU:")
}
getDescribe 'EnableMono'{
   It 'Keeps current value.'{
      $initialState = Invoke-DscResource -Name EnableMono -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}

      $parameters = @{ MonoEnabledSetting = 'KeepCurrentValue' }

      $testResult = Invoke-DscResource -Name EnableMono -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true

      # Invoking set should not change these values.
      Invoke-DscResource -Name EnableMono -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
      $finalState = Invoke-DscResource -Name EnableMono -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
      $finalState.MonoEnabledSetting | Should -Be $initialState.MonoEnabledSetting
   }

   It 'Sets desired value.'{
      # Randomly generate desired state. Minimum is set to 1 to avoid using KeepCurrentValue
      $desiredMonoEnabledSetting = [MonoEnabledSetting](Get-Random -Maximum 2 -Minimum 1)

      $desiredState = @{ MonoEnabledSetting = $desiredMonoEnabledSetting }

      Invoke-DscResource -Name EnableMono -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name EnableMono -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
      $finalState.MonoEnabledSetting | Should -Be $desiredMonoEnabledSetting
	  
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

AfterAll {
   $env:TestRegistryPath = ""
}