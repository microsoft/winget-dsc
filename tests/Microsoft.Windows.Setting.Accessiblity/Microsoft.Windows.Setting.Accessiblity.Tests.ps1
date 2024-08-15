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
getDescribe 'DynamicScrollbars'{
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