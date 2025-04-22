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
      $initialState = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}

      $parameters = @{
         Alignment      = 'KeepCurrentValue'
         HideLabelsMode = 'KeepCurrentValue'
         SearchboxMode  = 'KeepCurrentValue'
         TaskViewButton = 'KeepCurrentValue'
         WidgetsButton  = 'KeepCurrentValue'
      }

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

      $desiredState = @{ Alignment = $desiredAlignment
         HideLabelsMode            = $desiredHideLabelsMode
         SearchboxMode             = $desiredSearchboxMode
         TaskViewButton            = $desiredTaskViewButton
         WidgetsButton             = $desiredWidgetsButton
      }

      Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Alignment | Should -Be $desiredAlignment
      $finalState.HideLabelsMode | Should -Be $desiredHideLabelsMode
      $finalState.SearchboxMode | Should -Be $desiredSearchboxMode
      $finalState.TaskViewButton | Should -Be $desiredTaskViewButton
      $finalState.WidgetsButton | Should -Be $desiredWidgetsButton
   }
}

Describe 'WindowsExplorer' {
   It 'Keeps current value.' {
      $initialState = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}

      $parameters = @{
         FileExtensions = 'KeepCurrentValue'
         HiddenFiles    = 'KeepCurrentValue'
         ItemCheckBoxes = 'KeepCurrentValue'
      }

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
         FileExtensions = $desiredFileExtensions
         HiddenFiles    = $desiredHiddenFiles
         ItemCheckBoxes = $desiredItemCheckBoxes
      }

      Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name WindowsExplorer -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.FileExtensions | Should -Be $desiredFileExtensions
      $finalState.HiddenFiles | Should -Be $desiredHiddenFiles
      $finalState.ItemCheckBoxes | Should -Be $desiredItemCheckBoxes
   }
}

Describe 'UserAccessControl' {
   It 'Keeps current value.' {
      $initialState = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}

      $parameters = @{ AdminConsentPromptBehavior = 'KeepCurrentValue' }

      $testResult = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Test -Property $parameters
      $testResult.InDesiredState | Should -Be $true

      # Invoking set should not change these values.
      Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Set -Property $parameters
      $finalState = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.AdminConsentPromptBehavior | Should -Be $initialState.AdminConsentPromptBehavior
   }

   It 'Sets desired value.' {
      # Randomly generate desired state. Minimum is set to 1 to avoid using KeepCurrentValue
      $desiredAdminConsentPromptBehavior = [AdminConsentPromptBehavior](Get-Random -Maximum 6 -Minimum 1)

      $desiredState = @{ AdminConsentPromptBehavior = $desiredAdminConsentPromptBehavior }

      Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name UserAccessControl -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.AdminConsentPromptBehavior | Should -Be $desiredAdminConsentPromptBehavior
   }
}

Describe 'EnableRemoteDesktop' {
   It 'Sets Enabled' {
      $desiredRemoteDesktopBehavior = [Ensure]::Present
      $desiredState = @{ Ensure = $desiredRemoteDesktopBehavior }

      Invoke-DscResource -Name EnableRemoteDesktop -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name EnableRemoteDesktop -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be $desiredRemoteDesktopBehavior
   }

   It 'Sets Disabled' {
      $desiredRemoteDesktopBehavior = [Ensure]::Absent
      $desiredState = @{ Ensure = $desiredRemoteDesktopBehavior }

      Invoke-DscResource -Name EnableRemoteDesktop -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name EnableRemoteDesktop -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be $desiredRemoteDesktopBehavior
   }
}

Describe 'EnableLongPathSupport' {
   It 'Sets Enabled' {
      $desiredLongPathsBehavior = [Ensure]::Present
      $desiredState = @{ Ensure = $desiredLongPathsBehavior }

      Invoke-DscResource -Name EnableLongPathSupport -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name EnableLongPathSupport -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be $desiredLongPathsBehavior
   }

   It 'Sets Disabled' {
      $desiredLongPathsBehavior = [Ensure]::Absent
      $desiredState = @{ Ensure = $desiredLongPathsBehavior }

      Invoke-DscResource -Name EnableLongPathSupport -ModuleName Microsoft.Windows.Developer -Method Set -Property $desiredState

      $finalState = Invoke-DscResource -Name EnableLongPathSupport -ModuleName Microsoft.Windows.Developer -Method Get -Property @{}
      $finalState.Ensure | Should -Be $desiredLongPathsBehavior
   }
}

# InModuleScope ensures that all mocks are on the Microsoft.Windows.Setting.System module.
InModuleScope Microsoft.Windows.Developer {
   Describe 'PowerPlanSetting' {
      BeforeAll {
         # disable group policy logic for tests
         Mock Backup-GroupPolicyPowerPlanSetting {}
         Mock Restore-GroupPolicyPowerPlanSetting {}
         Mock Disable-GroupPolicyPowerPlanSetting {}

         # Disable tests from editing actual values
         Mock Set-CimInstance {} -RemoveParameterType InputObject

         function PowerPlanSettingGetTests([PowerPlanSettingName]$PowerPlanSettingName) {
            $SettingGUID = ($PowerPlanSettingName -eq [PowerPlanSettingName]::DisplayTimeout) ? '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e' : '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
            $expectedPluggedInValue = Get-Random -Maximum 18000 -Minimum 0
            $expectedBatteryValue = Get-Random -Maximum 18000 -Minimum 0

            Mock Get-CimInstance {
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerPlan\{00000000-0000-0000-0000-000000000000}'; IsActive = $true }
            } -ParameterFilter { $ClassName -eq 'win32_PowerPlan' }

            Mock Get-CimInstance {
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerSettingDataIndex\{{00000000-0000-0000-0000-000000000000}}\AC\{{{0}}}' -f $SettingGUID; SettingIndexValue = $expectedPluggedInValue }
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerSettingDataIndex\{{00000000-0000-0000-0000-000000000000}}\DC\{{{0}}}' -f $SettingGUID; SettingIndexValue = $expectedBatteryValue }
            } -ParameterFilter { $ClassName -eq 'Win32_PowerSettingDataIndex' }

            $powerPlanSettingProvider = [PowerPlanSetting]@{
               Name         = $PowerPlanSettingName
               SettingValue = 0
               PowerSource  = [PowerSource]::All
            }

            $getResourceResult = $powerPlanSettingProvider.Get()
            $getResourceResult.Name | Should -Be $PowerPlanSettingName
            $getResourceResult.SettingValue | Should -Be 0
            $getResourceResult.PluggedInValue | Should -Be $expectedPluggedInValue
            $getResourceResult.BatteryValue | Should -Be $expectedBatteryValue
         }

         function PowerPlanSettingTestTests([PowerPlanSettingName]$PowerPlanSettingName, [PowerSource]$PowerSource, [bool]$ExpectedValue) {
            $SettingGUID = ($PowerPlanSettingName -eq [PowerPlanSettingName]::DisplayTimeout) ? '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e' : '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
            $expectedSettingValue = Get-Random -Maximum 18000 -Minimum 1

            if ($ExpectedValue -eq $true) {
               $expectedPluggedInValue = ($PowerSource -ne [PowerSource]::Battery) ? $expectedSettingValue : 0
               $expectedBatteryValue = ($PowerSource -ne [PowerSource]::PluggedIn) ? $expectedSettingValue : 0
            } else {
               $expectedPluggedInValue = 0
               $expectedBatteryValue = 0
            }


            Mock Get-CimInstance {
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerPlan\{00000000-0000-0000-0000-000000000000}'; IsActive = $true }
            } -ParameterFilter { $ClassName -eq 'win32_PowerPlan' }

            Mock Get-CimInstance {
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerSettingDataIndex\{{00000000-0000-0000-0000-000000000000}}\AC\{{{0}}}' -f $SettingGUID; SettingIndexValue = $expectedPluggedInValue }
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerSettingDataIndex\{{00000000-0000-0000-0000-000000000000}}\DC\{{{0}}}' -f $SettingGUID; SettingIndexValue = $expectedBatteryValue }
            } -ParameterFilter { $ClassName -eq 'Win32_PowerSettingDataIndex' }

            $powerPlanSettingProvider = [PowerPlanSetting]@{
               Name         = $PowerPlanSettingName
               SettingValue = $expectedSettingValue
               PowerSource  = $PowerSource
            }

            $testResourceResult = $powerPlanSettingProvider.Test()
            $testResourceResult | Should -Be $ExpectedValue
         }

         function PowerPlanSettingSetTests([PowerPlanSettingName]$PowerPlanSettingName, [PowerSource]$PowerSource, [bool]$IsInTargetState) {
            $SettingGUID = ($PowerPlanSettingName -eq [PowerPlanSettingName]::DisplayTimeout) ? '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e' : '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
            $expectedSettingValue = Get-Random -Maximum 18000 -Minimum 1


            if ($IsInTargetState -eq $true) {
               $expectedGetInvocations = 2
               $expectedSetInvocations = 0
               $expectedPluggedInValue = ($PowerSource -ne [PowerSource]::Battery) ? $expectedSettingValue : 0
               $expectedBatteryValue = ($PowerSource -ne [PowerSource]::PluggedIn) ? $expectedSettingValue : 0
            } else {
               $expectedGetInvocations = ($PowerSource -eq [PowerSource]::All) ? 4 : 3
               $expectedSetInvocations = ($PowerSource -eq [PowerSource]::All) ? 2 : 1
               $expectedPluggedInValue = 0
               $expectedBatteryValue = 0
            }

            Mock Get-CimInstance {
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerPlan\{00000000-0000-0000-0000-000000000000}'; IsActive = $true }
            } -ParameterFilter { $ClassName -eq 'win32_PowerPlan' }

            Mock Get-CimInstance {
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerSettingDataIndex\{{00000000-0000-0000-0000-000000000000}}\AC\{{{0}}}' -f $SettingGUID; SettingIndexValue = $expectedPluggedInValue }
               [PSCustomObject]@{ InstanceID = 'Microsoft:PowerSettingDataIndex\{{00000000-0000-0000-0000-000000000000}}\DC\{{{0}}}' -f $SettingGUID; SettingIndexValue = $expectedBatteryValue }
            } -ParameterFilter { $ClassName -eq 'Win32_PowerSettingDataIndex' }

            $powerPlanSettingProvider = [PowerPlanSetting]@{
               Name         = $PowerPlanSettingName
               SettingValue = $expectedSettingValue
               PowerSource  = $PowerSource
            }

            $powerPlanSettingProvider.Set()

            Should -Invoke Get-CimInstance -Times $expectedGetInvocations -Exactly -ParameterFilter { $ClassName -eq 'Win32_PowerSettingDataIndex' }
            Should -Invoke Set-CimInstance -Times $expectedSetInvocations -Exactly
         }
      }

      Context 'Get' {
         It 'Get test for display timeout' {
            PowerPlanSettingGetTests -PowerPlanSettingName DisplayTimeout
         }

         It 'Get test for sleep timeout' {
            PowerPlanSettingGetTests -PowerPlanSettingName SleepTimeout
         }
      }

      Context 'Test' {
         It 'PowerPlanSetting Test test for display timeout on battery being configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName DisplayTimeout -PowerSource Battery -ExpectedValue $true
         }

         It 'PowerPlanSetting Test test for display timeout on battery being not configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName DisplayTimeout -PowerSource Battery -ExpectedValue $false
         }

         It 'PowerPlanSetting Test test for display timeout on wall power being configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName DisplayTimeout -PowerSource Battery -ExpectedValue $true
         }

         It 'PowerPlanSetting Test test for display timeout on wall power being not configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName DisplayTimeout -PowerSource Battery -ExpectedValue $false
         }

         It 'PowerPlanSetting Test test for display timeout being configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName DisplayTimeout -PowerSource All -ExpectedValue $true
         }

         It 'PowerPlanSetting Test test for display timeout being not configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName DisplayTimeout -PowerSource All -ExpectedValue $false
         }

         It 'PowerPlanSetting Test test for sleep timeout on battery being configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName SleepTimeout -PowerSource Battery -ExpectedValue $true
         }

         It 'PowerPlanSetting Test test for sleep timeout on battery being not configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName SleepTimeout -PowerSource Battery -ExpectedValue $false
         }

         It 'PowerPlanSetting Test test for sleep timeout on wall power being configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName SleepTimeout -PowerSource Battery -ExpectedValue $true
         }

         It 'PowerPlanSetting Test test for sleep timeout on wall power being not configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName SleepTimeout -PowerSource Battery -ExpectedValue $false
         }

         It 'PowerPlanSetting Test test for sleep timeout  being configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName SleepTimeout -PowerSource All -ExpectedValue $true
         }

         It 'PowerPlanSetting Test test for sleep timeout being not configured' {
            PowerPlanSettingTestTests -PowerPlanSettingName SleepTimeout -PowerSource All -ExpectedValue $false
         }
      }

      Context 'Set' {
         It 'PowerPlanSetting Set test for display timeout on battery being configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName DisplayTimeout -PowerSource Battery -IsInTargetState $True
         }

         It 'PowerPlanSetting Set test for display timeout on battery being not configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName DisplayTimeout -PowerSource Battery -IsInTargetState $false
         }

         It 'PowerPlanSetting Set test for display timeout on wall power being configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName DisplayTimeout -PowerSource Battery -IsInTargetState $true
         }

         It 'PowerPlanSetting Set test for display timeout on wall power being not configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName DisplayTimeout -PowerSource Battery -IsInTargetState $false
         }

         It 'PowerPlanSetting Set test for display timeout being configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName DisplayTimeout -PowerSource All -IsInTargetState $true
         }

         It 'PowerPlanSetting Set test for display timeout being not configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName DisplayTimeout -PowerSource All -IsInTargetState $false
         }

         It 'PowerPlanSetting Set test for sleep timeout on battery being configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName SleepTimeout -PowerSource Battery -IsInTargetState $true
         }

         It 'PowerPlanSetting Set test for sleep timeout on battery being not configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName SleepTimeout -PowerSource Battery -IsInTargetState $false
         }

         It 'PowerPlanSetting Set test for sleep timeout on wall power being configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName SleepTimeout -PowerSource Battery -IsInTargetState $true
         }

         It 'PowerPlanSetting Set test for sleep timeout on wall power being not configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName SleepTimeout -PowerSource Battery -IsInTargetState $false
         }

         It 'PowerPlanSetting Set test for sleep timeout  being configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName SleepTimeout -PowerSource All -IsInTargetState $true
         }

         It 'PowerPlanSetting Set test for sleep timeout being not configured' {
            PowerPlanSettingSetTests -PowerPlanSettingName SleepTimeout -PowerSource All -IsInTargetState $false
         }

      }
   }
}

AfterAll {
   $env:TestRegistryPath = ''
}
