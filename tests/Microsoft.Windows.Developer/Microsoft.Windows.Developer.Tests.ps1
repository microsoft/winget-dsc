# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Developer

$ErrorActionPreference = 'Stop'
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
   $env:TestRegistryPath = ((Get-Item -Path TestRegistry:\).Name).replace('HKEY_CURRENT_USER', 'HKCU:')
}

Describe 'List available DSC resources' {
   It 'Shows DSC Resources' {
      $expectedDSCResources = 'DeveloperMode', 'OsVersion', 'ShowSecondsInClock', 'EnableDarkMode', 'Taskbar', 'UserAccessControl', 'WindowsExplorer', 'EnableRemoteDesktop', 'EnableLongPathSupport', 'PowerPlanSetting'
      $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Developer).Name
      $availableDSCResources.length | Should -Be $expectedDSCResources.Length
      $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
   }
}

Describe 'Taskbar' {
   It 'Keeps current value.' {
      $initialState = Invoke-DscResource -name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}

      $parameters = @{
         Alignment      = 'KeepCurrentValue'
         HideLabelsMode = 'KeepCurrentValue'
         SearchboxMode  = 'KeepCurrentValue'
         TaskViewButton = 'KeepCurrentValue'
         WidgetsButton  = 'KeepCurrentValue'
      }

      $testResult = Invoke-DscResource -name Taskbar -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true

      # Invoking set should not change these values.
      Invoke-DscResource -name Taskbar -ModuleName Microsoft.Windows.Developer -Method Set -Property $parameters
      $finalState = Invoke-DscResource -name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
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

      $desiredState = @{ Alignment = $desiredAlignment
         HideLabelsMode            = $desiredHideLabelsMode
         SearchboxMode             = $desiredSearchboxMode
         TaskViewButton            = $desiredTaskViewButton
         WidgetsButton             = $desiredWidgetsButton
      }

      Invoke-DscResource -name Taskbar -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Alignment | Should -Be $desiredAlignment
      $finalState.HideLabelsMode | Should -Be $desiredHideLabelsMode
      $finalState.SearchboxMode | Should -Be $desiredSearchboxMode
      $finalState.TaskViewButton | Should -Be $desiredTaskViewButton
      $finalState.WidgetsButton | Should -Be $desiredWidgetsButton
   }
}

Describe 'WindowsExplorer' {
   It 'Keeps current value.' {
      $initialState = Invoke-DscResource -name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}

      $parameters = @{
         FileExtensions = 'KeepCurrentValue'
         HiddenFiles    = 'KeepCurrentValue'
         ItemCheckBoxes = 'KeepCurrentValue'
      }

      $testResult = Invoke-DscResource -name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true

      # Invoking set should not change these values.
      Invoke-DscResource -name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Set -Property $parameters
      $finalState = Invoke-DscResource -name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
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
         FileExtensions = $desiredFileExtensions
         HiddenFiles    = $desiredHiddenFiles
         ItemCheckBoxes = $desiredItemCheckBoxes
      }

      Invoke-DscResource -name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.FileExtensions | Should -Be $desiredFileExtensions
      $finalState.HiddenFiles | Should -Be $desiredHiddenFiles
      $finalState.ItemCheckBoxes | Should -Be $desiredItemCheckBoxes
   }
}

Describe 'UserAccessControl' {
   It 'Keeps current value.' {
      $initialState = Invoke-DscResource -name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}

      $parameters = @{ AdminConsentPromptBehavior = 'KeepCurrentValue' }

      $testResult = Invoke-DscResource -name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true

      # Invoking set should not change these values.
      Invoke-DscResource -name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Set -Property $parameters
      $finalState = Invoke-DscResource -name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.AdminConsentPromptBehavior | Should -Be $initialState.AdminConsentPromptBehavior
   }

   It 'Sets desired value.' {
      # Randomly generate desired state. Minimum is set to 1 to avoid using KeepCurrentValue
      $desiredAdminConsentPromptBehavior = [AdminConsentPromptBehavior](Get-Random -Maximum 6 -Minimum 1)

      $desiredState = @{ AdminConsentPromptBehavior = $desiredAdminConsentPromptBehavior }

      Invoke-DscResource -name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.AdminConsentPromptBehavior | Should -Be $desiredAdminConsentPromptBehavior
   }
}

Describe 'EnableRemoteDesktop' {
   It 'Sets Enabled' {
      $desiredRemoteDesktopBehavior = [Ensure]::Present
      $desiredState = @{ Ensure = $desiredRemoteDesktopBehavior }

      Invoke-DscResource -name EnableRemoteDesktop -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -name EnableRemoteDesktop -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be $desiredRemoteDesktopBehavior
   }

   It 'Sets Disabled' {
      $desiredRemoteDesktopBehavior = [Ensure]::Absent
      $desiredState = @{ Ensure = $desiredRemoteDesktopBehavior }

      Invoke-DscResource -name EnableRemoteDesktop -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -name EnableRemoteDesktop -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be $desiredRemoteDesktopBehavior
   }
}

Describe 'EnableLongPathSupport' {
   It 'Sets Enabled' {
      $desiredLongPathsBehavior = [Ensure]::Present
      $desiredState = @{ Ensure = $desiredLongPathsBehavior }

      Invoke-DscResource -name EnableLongPathSupport -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -name EnableLongPathSupport -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be $desiredLongPathsBehavior
   }

   It 'Sets Disabled' {
      $desiredLongPathsBehavior = [Ensure]::Absent
      $desiredState = @{ Ensure = $desiredLongPathsBehavior }

      Invoke-DscResource -name EnableLongPathSupport -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -name EnableLongPathSupport -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be $desiredLongPathsBehavior
   }
}

# InModuleScope ensures that all mocks are on the Microsoft.Windows.Setting.System module.
InModuleScope Microsoft.Windows.Developer {
   Describe 'PowerPlanSetting' {

      Context 'Get' {
         It 'Get test' {
            # disable group policy logic for tests
            Mock Backup-GroupPolicyPowerPlanSetting {}
            Mock Restore-GroupPolicyPowerPlanSetting {}
            Mock Disable-GroupPolicyPowerPlanSetting {}

            Mock Get-CimInstance {
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerPlan\{00000000-0000-0000-0000-000000000000}'; IsActive = $true }
            } -ParameterFilter { $ClassName -eq 'win32_PowerPlan' }

            <#
            Mock Get-CimInstance {
               New-MockObject -Properties @{ InstanceID = 'Microsoft:PowerSettingDataIndex\{{00000000-0000-0000-0000-000000000000}}\AC\{{3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e}}'; SettingIndexValue = 0 }
               New-MockObject -Properties @{ InstanceID = 'Microsoft:PowerSettingDataIndex\{{00000000-0000-0000-0000-000000000000}}\DC\{{3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e}}'; SettingIndexValue = 0 }
            } -ParameterFilter { ($Name -eq 'root\cimv2\power') -and ($Class -eq 'Win32_PowerSettingDataIndex') }
             #>

            $powerPlanSettingProvider = [PowerPlanSetting]@{
               Name         = [PowerPlanSettingName]::DisplayTimeout
               SettingValue = 0
            }

            $getResourceResult = $powerPlanSettingProvider.Get()
            $getResourceResult.Name | Should -Be ([PowerPlanSettingName]::DisplayTimeout)
            $getResourceResult.SettingValue | Should -Be 0
            $getResourceResult.PluggedInValue | Should -Be 0
            $getResourceResult.BatteryValue | Should -Be 0
         }
      }
   }
}

AfterAll {
   $env:TestRegistryPath = ''
}
