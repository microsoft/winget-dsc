# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Developer

<#
.Synopsis
   Pester tests related to the Microsoft.WinGet.Developer PowerShell module.
#>

BeforeAll {
   Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
   Import-Module Microsoft.Windows.Developer
}

Describe 'List available DSC resources'{
   It 'Shows DSC Resources'{
       $expectedDSCResources = "DeveloperMode", "OsVersion", "ShowSecondsInClock", "EnableDarkMode", "Taskbar", "UserAccessControl", "WindowsExplorer"
       $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Developer).Name
       $availableDSCResources.length | Should -Be 7
       $availableDSCResources | Where-Object {$expectedDSCResources -notcontains $_} | Should -BeNullOrEmpty -ErrorAction Stop
   }
}

Describe 'Taskbar'{
   BeforeAll {
      # Retain inital state.
      $initialState = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
   }

   It 'Keeps current value.'{
      $parameters = @{ Alignment = 'KeepCurrentValue';
         HideLabelsMode = 'KeepCurrentValue';
         SearchboxMode = 'KeepCurrentValue';
         TaskViewButton = 'KeepCurrentValue';
         WidgetsButton = 'KeepCurrentValue'}

         $testResult = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
         $testResult.InDesiredState | Should -Be $true
   }

   It 'Sets desired value' {
      # Randomly generate desired state. Minimum is set to 1 to avoid KeepCurrentValue
      $desiredAlignment = [Alignment](Get-Random -Maximum 3 -Minimum 1)
      $desiredHideLabelsMode = [HideTaskBarLabelsBehavior](Get-Random -Maximum 4 -Minimum 1)
      $desiredSearchboxMode = [SearchBoxMode](Get-Random -Maximum 5 -Minimum 1)
      $desiredTaskViewButton = [ShowHideFeature](Get-Random -Maximum 3 -Minimum 1)
      $desiredWidgetsButton = [ShowHideFeature](Get-Random -Maximum 3 -Minimum 1)

      $desiredState = @{ Alignment = $desiredAlignment;
         HideLabelsMode = $desiredHideLabelsMode;
         SearchboxMode = $desiredSearchboxMode;
         TaskViewButton = $desiredTaskViewButton;
         WidgetsButton = $desiredWidgetsButton}
      
      Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState
   
      $finalState = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Alignment | Should -Be $desiredAlignment
      $finalState.HideLabelsMode | Should -Be $desiredHideLabelsMode
      $finalState.SearchboxMode | Should -Be $desiredSearchboxMode
      $finalState.TaskViewButton | Should -Be $desiredTaskViewButton
      $finalState.WidgetsButton | Should -Be $desiredWidgetsButton
   }

   AfterAll {
      # Revert back to initial state.
      $initialStateParameters = @{ Alignment = $initialState.Alignment;
         HideLabelsMode = $initialState.HideLabelsMode;
         SearchboxMode = $initialState.SearchboxMode;
         TaskViewButton = $initialState.TaskViewButton;
         WidgetsButton = $initialState.WidgetsButton}

      Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Set -Property $initialStateParameters
   }
}

Describe 'WindowsExplorer'{
   BeforeAll {
      # Retain inital state.
      $initialState = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
   }

   It 'Keeps current value.'{
      $parameters = @{ FileExtensions = 'KeepCurrentValue';
         HiddenFiles = 'KeepCurrentValue';
         ItemCheckBoxes = 'KeepCurrentValue' }

         $testResult = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
         $testResult.InDesiredState | Should -Be $true
   }

   It 'Sets desired value' {
      # Randomly generate desired state. Minimum is set to 1 to avoid using KeepCurrentValue
      $desiredFileExtensions = [ShowHideFeature](Get-Random -Maximum 3 -Minimum 1)
      $desiredHiddenFiles = [ShowHideFeature](Get-Random -Maximum 3 -Minimum 1)
      $desiredItemCheckBoxes = [ShowHideFeature](Get-Random -Maximum 3 -Minimum 1)

      $desiredState = @{ FileExtensions = $desiredFileExtensions;
         HiddenFiles = $desiredHiddenFiles;
         ItemCheckBoxes = $desiredItemCheckBoxes}
      
      Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState
   
      $finalState = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.FileExtensions | Should -Be $desiredFileExtensions
      $finalState.HiddenFiles | Should -Be $desiredHiddenFiles
      $finalState.ItemCheckBoxes | Should -Be $desiredItemCheckBoxes
   }

   AfterAll {
      # Revert back to initial state.
      $initialStateParameters = @{ FileExtensions = $initialState.FileExtensions;
         HiddenFiles = $initialState.HiddenFiles;
         ItemCheckBoxes = $initialState.ItemCheckBoxes}

      Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Set -Property $initialStateParameters
   }
}