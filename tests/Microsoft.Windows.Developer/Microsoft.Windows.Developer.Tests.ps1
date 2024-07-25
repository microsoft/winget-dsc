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
   It 'Keeps current value.'{
      $initialState = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $parameters = @{ AdminConsentPromptBehavior = 'KeepCurrentValue' }
      $testResult = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true
      
      # Invoking set should not change these values.
      Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Set -Property $parameters
      $finalState = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.AdminConsentPromptBehavior | Should -Be $initialState.AdminConsentPromptBehavior
   }
   It 'Sets desired value.'{
      # Randomly generate desired state. Minimum is set to 1 to avoid using KeepCurrentValue
      $desiredAdminConsentPromptBehavior = [AdminConsentPromptBehavior](Get-Random -Maximum 6 -Minimum 1)
      $desiredState = @{ AdminConsentPromptBehavior = $desiredAdminConsentPromptBehavior }
      
      Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState
   
      $finalState = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.AdminConsentPromptBehavior | Should -Be $desiredAdminConsentPromptBehavior
   }
}
Describe 'Animation'{
   It 'Keeps current value.'{
      $initialState = Invoke-DscResource -Name AnimationEffects -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}

      $parameters = @{ AnimationBehavior = 'KeepCurrentValue' }

      $testResult = Invoke-DscResource -Name AnimationEffects -ModuleName Microsoft.Windows.Setting.Accessibility -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true

      # Invoking set should not change these values.
      Invoke-DscResource -Name AnimationEffects -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $parameters
      $finalState = Invoke-DscResource -Name AnimationEffects -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
      $finalState.AnimationBehavior | Should -Be $initialState.AnimationBehavior
   }

   It 'Sets desired value.'{
      # Randomly generate desired state. Minimum is set to 1 to avoid using KeepCurrentValue
      $desiredAnimationBehavior = [AnimationBehavior]("Enabled","Disabled"|Get-Random)

      $desiredState = @{ AnimationBehavior = $desiredAnimationBehavior }

      Invoke-DscResource -Name AnimationEffects -ModuleName Microsoft.Windows.Setting.Accessibility -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name AnimationEffects -ModuleName Microsoft.Windows.Setting.Accessibility -Method Get -Property @{}
      $finalState.AnimationBehavior | Should -Be $desiredAnimationBehavior
      $finalState.SmoothScrollListBoxes | Should -Be $desiredAnimationBehavior
      $finalState.SlideOpenComboBoxes | Should -Be $desiredAnimationBehavior
      $finalState.FadeOrSlideMenusIntoView | Should -Be $desiredAnimationBehavior
      $finalState.ShowShadowsUnderMousePointer | Should -Be $desiredAnimationBehavior
      $finalState.FadeOrSlideToolTipsIntoView | Should -Be $desiredAnimationBehavior
      $finalState.FadeOrSlideToolTipsIntoView | Should -Be $desiredAnimationBehavior
      $finalState.ShowShadowsUnderWindows | Should -Be $desiredAnimationBehavior
	  
   }
}

AfterAll {
   $env:TestRegistryPath = ""
}