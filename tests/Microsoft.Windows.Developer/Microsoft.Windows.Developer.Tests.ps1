# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Developer

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.WinGet.Developer PowerShell module.
#>
# InModuleScope ensures that all mocks are on the Microsoft.Windows.Developer module.
InModuleScope Microsoft.Windows.Developer {
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
         $expectedDSCResources = @('DeveloperMode', 'OsVersion', 'ShowSecondsInClock', 'EnableDarkMode', 'Taskbar', 'UserAccessControl',
            'WindowsExplorer', 'EnableRemoteDesktop', 'EnableLongPathSupport', 'PowerPlanSetting', 'WindowsCapability',
            'NetConnectionProfile', 'NetConnectionProfileInfo')
         $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Developer).Name
         $availableDSCResources.length | Should -Be $expectedDSCResources.Count
         $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
      }
   }

   enum RegistryValueState {
      SetTrue
      SetFalse
      NotSet
   }

   Describe 'DeveloperMode' {

      BeforeAll {
         Mock Set-ItemProperty { }

         $script:devModePresentCommonResource = [DeveloperMode]@{
            Ensure = [Ensure]::Present
         }

         $script:devModeAbsentCommonResource = [DeveloperMode]@{
            Ensure = [Ensure]::Absent
         }
      }

      It 'Get test for RegistryValueState:<RegistryValueState>' -ForEach @(
         @{ RegistryValueState = [RegistryValueState]::SetTrue }
         @{ RegistryValueState = [RegistryValueState]::SetFalse }
         @{ RegistryValueState = [RegistryValueState]::SetFalse }
      ) {
         if ($RegistryValueState -eq [RegistryValueState]::NotSet) {
            Mock DoesRegistryKeyPropertyExist { return $false }
         } else {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return ($RegistryValueState -eq [RegistryValueState]::SetTrue) ? 1 : 0 }
         }

         $getResourceResult = $script:devModePresentCommonResource.Get()
         $expectedValue = ($RegistryValueState -eq [RegistryValueState]::SetTrue) ? 'Present' : 'Absent'
         $getResourceResult.Ensure | Should -Be $expectedValue
         $getResourceResult.IsEnabled | Should -Be ($RegistryValueState -eq [RegistryValueState]::SetTrue)

         if ($RegistryValueState -eq [RegistryValueState]::NotSet) {
            Should -Invoke DoesRegistryKeyPropertyExist -Times 1 -Exactly
         } else {
            Should -Invoke DoesRegistryKeyPropertyExist -Times 1 -Exactly
            Should -Invoke Get-ItemPropertyValue -Times 1 -Exactly
         }
      }

      It 'Test test for RegistryValueState:<RegistryValueState>, EnsureState:<EnsureState>' -ForEach @(
         @{ RegistryValueState = [RegistryValueState]::SetTrue; EnsureState = [Ensure]::Present }
         @{ RegistryValueState = [RegistryValueState]::SetFalse; EnsureState = [Ensure]::Present }
         @{ RegistryValueState = [RegistryValueState]::NotSet; EnsureState = [Ensure]::Present }
         @{ RegistryValueState = [RegistryValueState]::SetTrue; EnsureState = [Ensure]::Absent }
         @{ RegistryValueState = [RegistryValueState]::SetFalse; EnsureState = [Ensure]::Absent }
         @{ RegistryValueState = [RegistryValueState]::NotSet; EnsureState = [Ensure]::Absent }
      ) {
         if ($RegistryValueState -eq [RegistryValueState]::NotSet) {
            Mock DoesRegistryKeyPropertyExist { return $false }
         } else {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return ($RegistryValueState -eq [RegistryValueState]::SetTrue) ? 1 : 0 }
         }

         $devModeResource = ($EnsureState -eq [Ensure]::Present) ? $script:devModePresentCommonResource : $script:devModeAbsentCommonResource
         $testResourceResult = $devModeResource.Test()

         $expectedValue = ($EnsureState -eq [Ensure]::Present)
         if ($RegistryValueState -eq [RegistryValueState]::SetTrue) {
            $testResourceResult | Should -Be $expectedValue
         } else {
            $testResourceResult | Should -Be (-Not $expectedValue)
         }
      }

      It 'Set test for RegistryValueState:<RegistryValueState>, EnsureState:<EnsureState>, HasAdmin:<HasAdmin>' -ForEach @(
         @{ RegistryValueState = [RegistryValueState]::SetTrue; EnsureState = [Ensure]::Present; HasAdmin = $true }
         @{ RegistryValueState = [RegistryValueState]::SetFalse; EnsureState = [Ensure]::Present; HasAdmin = $true }
         @{ RegistryValueState = [RegistryValueState]::NotSet; EnsureState = [Ensure]::Present; HasAdmin = $true }
         @{ RegistryValueState = [RegistryValueState]::SetTrue; EnsureState = [Ensure]::Absent; HasAdmin = $true }
         @{ RegistryValueState = [RegistryValueState]::SetFalse; EnsureState = [Ensure]::Absent; HasAdmin = $true }
         @{ RegistryValueState = [RegistryValueState]::NotSet; EnsureState = [Ensure]::Absent; HasAdmin = $true }
         @{ RegistryValueState = [RegistryValueState]::SetTrue; EnsureState = [Ensure]::Present; HasAdmin = $false }
         @{ RegistryValueState = [RegistryValueState]::SetFalse; EnsureState = [Ensure]::Present; HasAdmin = $false }
         @{ RegistryValueState = [RegistryValueState]::NotSet; EnsureState = [Ensure]::Present; HasAdmin = $false }
         @{ RegistryValueState = [RegistryValueState]::SetTrue; EnsureState = [Ensure]::Absent; HasAdmin = $false }
         @{ RegistryValueState = [RegistryValueState]::SetFalse; EnsureState = [Ensure]::Absent; HasAdmin = $false }
         @{ RegistryValueState = [RegistryValueState]::NotSet; EnsureState = [Ensure]::Absent; HasAdmin = $false }
      ) {
         if ($RegistryValueState -eq [RegistryValueState]::NotSet) {
            Mock DoesRegistryKeyPropertyExist { return $false }
         } else {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return ($RegistryValueState -eq [RegistryValueState]::SetTrue) ? 1 : 0 }
         }

         Mock New-Object {
            New-MockObject -Type 'System.Security.Principal.WindowsPrincipal' -Methods @{ IsInRole = { param($windowsIdentity) $HasAdmin } }
         } -ParameterFilter { $TypeName -eq 'System.Security.Principal.WindowsPrincipal' }


         $devModeResource = ($EnsureState -eq [Ensure]::Present) ? $script:devModePresentCommonResource : $script:devModeAbsentCommonResource
         $setResult = { $devModeResource.Set() }

         if ((($EnsureState -eq [Ensure]::Present) -and ($RegistryValueState -eq [RegistryValueState]::SetTrue)) -or
      (($EnsureState -eq [Ensure]::Absent) -and ($RegistryValueState -ne [RegistryValueState]::SetTrue))) {
            # No action in these scenarios
            Should -Invoke Set-ItemProperty -Times 0 -Exactly
         } else {
            # Cannot take action without admin, otherwise update registry
            if (-Not $HasAdmin) {
               $setResult | Should -Throw
            } else {
               $setResult | Should -Not -Throw

               # If registry is set then we want to unset it
               $expectedWriteValue = ($RegistryValueState -eq [RegistryValueState]::SetTrue) ? 0 : 1
               Should -Invoke Set-ItemProperty -Times 1 -Exactly { $Value -eq $expectedWriteValue }
            }
         }
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

   Describe 'PowerPlanSetting' {
      BeforeAll {
         # disable group policy logic for tests
         Mock Backup-GroupPolicyPowerPlanSetting {}
         Mock Restore-GroupPolicyPowerPlanSetting {}
         Mock Disable-GroupPolicyPowerPlanSetting {}

         # Disable tests from editing actual values
         Mock Set-CimInstance {} -RemoveParameterType InputObject
      }

      It 'Get test for PowerPlanSettingName:<PowerPlanSettingName>' -ForEach @(
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout }
      ) {
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

      It 'Test test for PowerPlanSettingName:<PowerPlanSettingName>, PowerSource:<PowerSource>, ExpectedValue:<ExpectedValue>' -ForEach @(
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::All; ExpectedValue = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::PluggedIn; ExpectedValue = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::Battery; ExpectedValue = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::All; ExpectedValue = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::PluggedIn; ExpectedValue = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::Battery; ExpectedValue = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::All; ExpectedValue = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::PluggedIn; ExpectedValue = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::Battery; ExpectedValue = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::All; ExpectedValue = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::PluggedIn; ExpectedValue = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::Battery; ExpectedValue = $false }
      ) {
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

      It 'Set test for PowerPlanSettingName:<PowerPlanSettingName>, PowerSource:<PowerSource>, IsInTargetState:<IsInTargetState>' -ForEach @(
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::All; IsInTargetState = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::PluggedIn; IsInTargetState = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::Battery; IsInTargetState = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::All; IsInTargetState = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::PluggedIn; IsInTargetState = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::Battery; IsInTargetState = $true }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::All; IsInTargetState = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::PluggedIn; IsInTargetState = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::DisplayTimeout; PowerSource = [PowerSource]::Battery; IsInTargetState = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::All; IsInTargetState = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::PluggedIn; IsInTargetState = $false }
         @{ PowerPlanSettingName = [PowerPlanSettingName]::SleepTimeout; PowerSource = [PowerSource]::Battery; IsInTargetState = $false }
      ) {
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

   enum WindowsCapabilityState {
      Installed
      NotInstalled
      Nonexistent
   }

   Describe 'WindowsCapability' {
      BeforeAll {
         Mock Add-WindowsCapability {}
         Mock Remove-WindowsCapability {}

         $script:WindowsCapabilityName = 'OpenSSH.Server~~~~0.0.1.0'

         $script:windowsCapabilityPresentCommonProvider = [WindowsCapability]@{
            Ensure = [Ensure]::Present
            Name   = $script:WindowsCapabilityName
         }

         $script:windowsCapabilityAbsentCommonProvider = [WindowsCapability]@{
            Ensure = [Ensure]::Absent
            Name   = $script:WindowsCapabilityName
         }
      }

      It 'Get test for WindowsCapabilityState:<WindowsCapabilityState>' -ForEach @(
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Nonexistent }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::NotInstalled }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Installed }
      ) {
         $capabilityState = ($WindowsCapabilityState -eq [WindowsCapabilityState]::Installed) ? 'Installed' : 'NotPresent'
         $capabilityName = ($WindowsCapabilityState -eq [WindowsCapabilityState]::Nonexistent) ? '' : $script:WindowsCapabilityName

         Mock Get-WindowsCapability { return  @{  Name = $capabilityName; State = $capabilityState } }

         $getResourceBlock = { return $script:windowsCapabilityPresentCommonProvider.Get() }
         if ($WindowsCapabilityState -eq [WindowsCapabilityState]::Nonexistent) {
            $getResourceBlock | Should -Throw
         } else {
            $getResourceResult = &$getResourceBlock
            $expectedEnsureValue = ($WindowsCapabilityState -eq [WindowsCapabilityState]::Installed) ? 'Present' : 'Absent'
            $getResourceResult.Ensure | Should -Be $expectedEnsureValue
            $getResourceResult.Name | Should -Be $script:WindowsCapabilityName
         }

         Should -Invoke Get-WindowsCapability -Times 1 -Exactly -ParameterFilter {
            $Name -eq $script:WindowsCapabilityName -and $Online -eq $true
         }
      }

      It 'Test test for WindowsCapabilityState:<WindowsCapabilityState>, EnsureState:<EnsureState>' -ForEach @(
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Nonexistent; EnsureState = [Ensure]::Present }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::NotInstalled; EnsureState = [Ensure]::Present }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Installed; EnsureState = [Ensure]::Present }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Nonexistent; EnsureState = [Ensure]::Absent }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::NotInstalled; EnsureState = [Ensure]::Absent }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Installed; EnsureState = [Ensure]::Absent }
      ) {
         $capabilityState = ($WindowsCapabilityState -eq [WindowsCapabilityState]::Installed) ? 'Installed' : 'NotPresent'
         $capabilityName = ($WindowsCapabilityState -eq [WindowsCapabilityState]::Nonexistent) ? '' : $script:WindowsCapabilityName

         Mock Get-WindowsCapability { return  @{  Name = $capabilityName; State = $capabilityState } }

         $winCapResource = ($EnsureState -eq [Ensure]::Present) ? $script:windowsCapabilityPresentCommonProvider : $script:windowsCapabilityAbsentCommonProvider

         $testResourceBlock = { return $winCapResource.Test() }
         if ($WindowsCapabilityState -eq [WindowsCapabilityState]::Nonexistent) {
            $testResourceBlock | Should -Throw
         } else {
            $testResourceResult = &$testResourceBlock
            $expectedValue = ($EnsureState -eq [Ensure]::Present)
            if ($WindowsCapabilityState -eq [WindowsCapabilityState]::Installed) {
               $testResourceResult | Should -Be $expectedValue
            } else {
               $testResourceResult | Should -Be (-Not $expectedValue)
            }
         }
      }

      It 'Set test for WindowsCapabilityState:<WindowsCapabilityState>, EnsureState:<EnsureState>' -ForEach @(
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Nonexistent; EnsureState = [Ensure]::Present }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::NotInstalled; EnsureState = [Ensure]::Present }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Installed; EnsureState = [Ensure]::Present }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Nonexistent; EnsureState = [Ensure]::Absent }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::NotInstalled; EnsureState = [Ensure]::Absent }
         @{ WindowsCapabilityState = [WindowsCapabilityState]::Installed; EnsureState = [Ensure]::Absent }
      ) {
         $capabilityState = ($WindowsCapabilityState -eq [WindowsCapabilityState]::Installed) ? 'Installed' : 'NotPresent'
         $capabilityName = ($WindowsCapabilityState -eq [WindowsCapabilityState]::Nonexistent) ? '' : $script:WindowsCapabilityName

         Mock Get-WindowsCapability { return  @{  Name = $capabilityName; State = $capabilityState } }

         $winCapResource = ($EnsureState -eq [Ensure]::Present) ? $script:windowsCapabilityPresentCommonProvider : $script:windowsCapabilityAbsentCommonProvider

         $setResourceBlock = { $winCapResource.Set() }
         if ($WindowsCapabilityState -eq [WindowsCapabilityState]::Nonexistent) {
            $setResourceBlock | Should -Throw
         } else {
            $setResourceBlock | Should -Not -Throw

            if ((($EnsureState -eq [Ensure]::Present) -and ($WindowsCapabilityState -eq [WindowsCapabilityState]::Installed)) -or
      (($EnsureState -eq [Ensure]::Absent) -and ($WindowsCapabilityState -eq [WindowsCapabilityState]::NotInstalled))) {
               # No action in these scenarios
               Should -Invoke Add-WindowsCapability -Times 0 -Exactly
               Should -Invoke Remove-WindowsCapability -Times 0 -Exactly
            } else {
               if ($WindowsCapabilityState -eq [WindowsCapabilityState]::NotInstalled) {
                  Should -Invoke Add-WindowsCapability -Times 1 -Exactly -ParameterFilter {
                     $Name -eq $script:WindowsCapabilityName -and $Online -eq $true
                  }
               } else {
                  Should -Invoke Remove-WindowsCapability -Times 1 -Exactly -ParameterFilter {
                     $Name -eq $script:WindowsCapabilityName -and $Online -eq $true
                  }
               }
            }
         }
      }
   }

   Describe 'NetConnectionProfile' {
      BeforeAll {
         Mock Set-NetConnectionProfile {}
      }

      It 'Get test for TargetInterfaceAlias:<TargetInterfaceAlias>, NetworkCategory:<NetworkCategory>, ProfileExists:<ProfileExists>' -ForEach @(
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; ProfileExists = $true }
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; ProfileExists = $false }
      ) {
         #Scoping workaround for the mock to work in the test
         $netCategory = $NetworkCategory
         Mock Get-NetConnectionProfile {
            if ($ProfileExists -eq $true) {
               return @{ NetworkCategory = $netCategory }
            } else {
               return $null
            }
         }

         $resource = [NetConnectionProfile]::new()
         $resource.InterfaceAlias = $TargetInterfaceAlias

         $resultBlock = { $resource.Get() }

         if ($ProfileExists -eq $true) {
            $result = &$resultBlock
            $result.InterfaceAlias | Should -Be $TargetInterfaceAlias
            $result.NetworkCategory | Should -Be $NetworkCategory
         } else {
            $resultBlock | Should -Throw
         }

         Should -Invoke Get-NetConnectionProfile -Times 1 -Exactly -ParameterFilter { $InterfaceAlias -eq $TargetInterfaceAlias }
      }

      It 'Test test for TargetInterfaceAlias:<TargetInterfaceAlias>, NetworkCategory:<NetworkCategory>, ExpectedResult:<ExpectedResult>, ProfileExists:<ProfileExists>' -ForEach @(
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; ExpectedResult = $true; ProfileExists = $true }
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; ExpectedResult = $false; ProfileExists = $true }
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; ExpectedResult = $true; ProfileExists = $false }
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; ExpectedResult = $false; ProfileExists = $false }
      ) {
         #Scoping workaround for the mock to work in the test
         $netCategory = $NetworkCategory
         Mock -CommandName Get-NetConnectionProfile {
            if ($ProfileExists -eq $true) {
               return @{ NetworkCategory = ($ExpectedResult ? $netCategory : 'Other') }
            } else {
               return $null
            }
         }

         $resource = [NetConnectionProfile]::new()
         $resource.InterfaceAlias = $TargetInterfaceAlias
         $resource.NetworkCategory = $NetworkCategory

         $resultBlock = { $resource.Test() }

         if ($ProfileExists -eq $true) {
            $result = &$resultBlock
            $result | Should -Be $ExpectedResult
         } else {
            $resultBlock | Should -Throw
         }
      }

      It 'Set test for TargetInterfaceAlias:<TargetInterfaceAlias>, NetworkCategory:<NetworkCategory>, IsInTargetState:<IsInTargetState>, ProfileExists:<ProfileExists>' -ForEach @(
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; IsInTargetState = $true; ProfileExists = $true }
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; IsInTargetState = $false; ProfileExists = $true }
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; IsInTargetState = $true; ProfileExists = $false }
         @{ TargetInterfaceAlias = 'Ethernet'; NetworkCategory = 'Private'; IsInTargetState = $false; ProfileExists = $false }
      ) {
         #Scoping workaround for the mock to work in the test
         $netCategory = $NetworkCategory
         Mock -CommandName Get-NetConnectionProfile {
            if ($ProfileExists -eq $true) {
               return @{ NetworkCategory = ($IsInTargetState ? $netCategory : 'Other') }
            } else {
               return $null
            }
         }

         $resource = [NetConnectionProfile]::new()
         $resource.InterfaceAlias = $TargetInterfaceAlias
         $resource.NetworkCategory = $NetworkCategory

         $resultBLock = { $resource.Set() }

         if ($ProfileExists -eq $true) {
            $resultBlock | Should -Not -Throw
            Should -Invoke Set-NetConnectionProfile -Exactly ($IsInTargetState ? 0 : 1)
         } else {
            $resultBlock | Should -Throw
         }
      }
   }

   Describe 'NetConnectionProfileInfo' {
      It 'Get test for TargetInterfaceAlias:<TargetInterfaceAlias>' -ForEach @(
         @{ TargetInterfaceAlias = 'Ethernet' }
      ) {
         Mock Get-NetConnectionProfile {
            return @{ }
         }

         $resource = [NetConnectionProfileInfo]::new()
         $resource.InterfaceAlias = $TargetInterfaceAlias

         $result = $resource.Get()
         $result.InterfaceAlias | Should -Be $TargetInterfaceAlias
      }

      It 'Test test for TargetInterfaceAlias:<TargetInterfaceAlias>, ProfileExists:<ProfileExists>' -ForEach @(
         @{ TargetInterfaceAlias = 'Ethernet'; ProfileExists = $true }
         @{ TargetInterfaceAlias = 'Ethernet'; ProfileExists = $false }
      ) {
         Mock -CommandName Get-NetConnectionProfile {
            if ($ProfileExists -eq $true) {
               return @{ }
            } else {
               return $null
            }
         }

         $resource = [NetConnectionProfileInfo]::new()
         $resource.InterfaceAlias = $TargetInterfaceAlias

         $result = $resource.Test()
         $result | Should -Be $ProfileExists
         Should -Invoke Get-NetConnectionProfile -Times 1 -Exactly -ParameterFilter { $InterfaceAlias -eq $TargetInterfaceAlias }
      }
   }

   AfterAll {
      $env:TestRegistryPath = ''
   }
}
