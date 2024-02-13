# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Developer

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.WinGet.Developer PowerShell module.
#>

BeforeAll {
   Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
   Import-Module Microsoft.Windows.Developer

   # Create test registry path.
   New-Item -Path TestRegistry:\ -Name TestKey
   # Set-ItemProperty requires the PSDrive to be in the format 'HKCU:'.
   $env:TestRegistryPath = ((Get-Item -Path TestRegistry:\).Name).replace("HKEY_CURRENT_USER", "HKCU:")
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
   It 'Keeps current value.'{
      $initialState = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}

      $parameters = @{
         Alignment = 'KeepCurrentValue';
         HideLabelsMode = 'KeepCurrentValue';
         SearchboxMode = 'KeepCurrentValue';
         TaskViewButton = 'KeepCurrentValue';
         WidgetsButton = 'KeepCurrentValue'}

      $testResult = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true

      # Invoking set should not change these values.
      Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Set -Property $parameters
      $finalState = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Alignment | Should -Be $initialState.Alignment
      $finalState.HideLabelsMode | Should -Be $initialState.HideLabelsMode
      $finalState.SearchboxMode | Should -Be $initialState.SearchboxMode
      $finalState.TaskViewButton | Should -Be $initialState.WidgetsButton
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
}

Describe 'WindowsExplorer'{
   It 'Keeps current value.'{
      $initialState = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}

      $parameters = @{
         FileExtensions = 'KeepCurrentValue';
         HiddenFiles = 'KeepCurrentValue';
         ItemCheckBoxes = 'KeepCurrentValue' }

      $testResult = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true
      
      # Invoking set should not change these values.
      Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Set -Property $parameters
      $finalState = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.FileExtensions | Should -Be $initialState.FileExtensions
      $finalState.HiddenFiles | Should -Be $initialState.HiddenFiles
      $finalState.ItemCheckBoxes | Should -Be $initialState.ItemCheckBoxes
   }

   It 'Sets desired value' {
      # Randomly generate desired state. Minimum is set to 1 to avoid using KeepCurrentValue
      $desiredFileExtensions = [ShowHideFeature](Get-Random -Maximum 3 -Minimum 1)
      $desiredHiddenFiles = [ShowHideFeature](Get-Random -Maximum 3 -Minimum 1)
      $desiredItemCheckBoxes = [ShowHideFeature](Get-Random -Maximum 3 -Minimum 1)

      $desiredState = @{
         FileExtensions = $desiredFileExtensions;
         HiddenFiles = $desiredHiddenFiles;
         ItemCheckBoxes = $desiredItemCheckBoxes}
      
      Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState
   
      $finalState = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.FileExtensions | Should -Be $desiredFileExtensions
      $finalState.HiddenFiles | Should -Be $desiredHiddenFiles
      $finalState.ItemCheckBoxes | Should -Be $desiredItemCheckBoxes
   }
}

Describe 'UserAccessControl'{
   It 'Sets desired value.'{
      Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Set -Property @{Ensure = 'Present'}

      $initialState = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $initialState.Ensure = [Ensure]::Present
      $initialState.Ensure | Should -Be 'Present'

      $testResult = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Test -Property @{Ensure = 'Absent'}
      $testResult.InDesiredState | Should -Be $false

      Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Set -Property @{Ensure = 'Absent'}
      $finalState = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be 'Absent'
   }
}

AfterAll {
   $env:TestRegistryPath = ""
}