# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Developer

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.WinGet.Developer PowerShell module.
#>

# InModuleScope ensures that all mocks are on the Microsoft.Windows.Setting.System module.
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
         $expectedDSCResources = 'DeveloperMode', 'OsVersion', 'ShowSecondsInClock', 'EnableDarkMode', 'Taskbar', 'UserAccessControl', 'WindowsExplorer', 'EnableRemoteDesktop', 'EnableLongPathSupport'
         $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Developer).Name
         $availableDSCResources.length | Should -Be 9
         $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
      }
   }

   $global:devModePresentCommonProvider = [DeveloperMode]@{
      Ensure = [Ensure]::Present
   }

   $global:devModeAbsentCommonProvider = [DeveloperMode]@{
      Ensure = [Ensure]::Absent
   }

   Describe 'DeveloperMode' {

      BeforeAll {
         Mock Set-ItemProperty { }
      }

      Context 'Get' {
         It 'Get returns present if registry value is set' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 1 }

            $getResourceResult = $global:devModePresentCommonProvider.Get()
            $getResourceResult.Ensure | Should -Be 'Present'

            Should -Invoke DoesRegistryKeyPropertyExist -Times 1 -Exactly
            Should -Invoke Get-ItemPropertyValue -Times 1 -Exactly
         }

         It 'Get returns absent if registry value is set to false' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 0 }

            $getResourceResult = $global:devModePresentCommonProvider.Get()
            $getResourceResult.Ensure | Should -Be 'Absent'

            Should -Invoke DoesRegistryKeyPropertyExist -Times 1 -Exactly
            Should -Invoke Get-ItemPropertyValue -Times 1 -Exactly
         }

         It 'Get returns absent if registry value does not exist' {
            Mock DoesRegistryKeyPropertyExist { return $false }

            $getResourceResult = $global:devModePresentCommonProvider.Get()
            $getResourceResult.Ensure | Should -Be 'Absent'

            Should -Invoke DoesRegistryKeyPropertyExist -Times 1 -Exactly
         }
      }

      Context 'Test' {
         It 'Test for presence returns true if registry value is set' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 1 }

            $testResourceResult = $global:devModePresentCommonProvider.Test()
            $testResourceResult | Should -BeTrue
         }

         It 'Test for presence returns false if registry value is set to false' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 0 }

            $testResourceResult = $global:devModePresentCommonProvider.Test()
            $testResourceResult | Should -BeFalse
         }

         It 'Test for presence returns false if registry value does not exist' {
            Mock DoesRegistryKeyPropertyExist { return $false }

            $testResourceResult = $global:devModePresentCommonProvider.Test()
            $testResourceResult | Should -BeFalse
         }

         It 'Test for absense returns false if registry value is set' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 1 }

            $testResourceResult = $global:devModeAbsentCommonProvider.Test()
            $testResourceResult | Should -BeFalse
         }

         It 'Test for absense returns true if registry value is set to false' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 0 }

            $testResourceResult = $global:devModeAbsentCommonProvider.Test()
            $testResourceResult | Should -BeTrue
         }

         It 'Test for absense returns true if registry value does not exist' {
            Mock DoesRegistryKeyPropertyExist { return $false }

            $testResourceResult = $global:devModeAbsentCommonProvider.Test()
            $testResourceResult | Should -BeTrue
         }
      }

      Context 'Set' {
         It 'Set throws if testing for presense and registry is not set' {
            Mock DoesRegistryKeyPropertyExist { return $false }

            Mock New-Object {
               New-MockObject -Type 'System.Security.Principal.WindowsPrincipal' -Methods @{ IsInRole = { param($windowsIdentity) $false } }
            } -ParameterFilter { $TypeName -eq 'System.Security.Principal.WindowsPrincipal' }

            { $global:devModePresentCommonProvider.Set() } | Should -Throw
         }

         It 'Set throws if testing for absense and registry is set' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 1 }

            Mock New-Object {
               New-MockObject -Type 'System.Security.Principal.WindowsPrincipal' -Methods @{ IsInRole = { param($windowsIdentity) $false } }
            } -ParameterFilter { $TypeName -eq 'System.Security.Principal.WindowsPrincipal' }

            { $global:devModeAbsentCommonProvider.Set() } | Should -Throw
         }

         It 'Set takes no action if testing for presense and registry is set' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 1 }

            $global:devModePresentCommonProvider.Set()

            Should -Invoke Set-ItemProperty -Times 0 -Exactly
         }

         It 'Set takes no action if testing for absense and registry is not set' {
            Mock DoesRegistryKeyPropertyExist { return $false }

            $global:devModeAbsentCommonProvider.Set()

            Should -Invoke Set-ItemProperty -Times 0 -Exactly
         }

         It 'Set takes action if testing for presense and registry is not set' {
            Mock DoesRegistryKeyPropertyExist { return $false }

            Mock New-Object {
               New-MockObject -Type 'System.Security.Principal.WindowsPrincipal' -Methods @{ IsInRole = { param($windowsIdentity) $true } }
            } -ParameterFilter { $TypeName -eq 'System.Security.Principal.WindowsPrincipal' }

            $global:devModePresentCommonProvider.Set()

            Should -Invoke Set-ItemProperty -Times 1 -Exactly -ParameterFilter { $Value -eq 1 }
         }

         It 'Set takes action if testing for absense and registry is set' {
            Mock DoesRegistryKeyPropertyExist { return $true }
            Mock Get-ItemPropertyValue { return 1 }

            Mock New-Object {
               New-MockObject -Type 'System.Security.Principal.WindowsPrincipal' -Methods @{ IsInRole = { param($windowsIdentity) $true } }
            } -ParameterFilter { $TypeName -eq 'System.Security.Principal.WindowsPrincipal' }

            $global:devModeAbsentCommonProvider.Set()

            Should -Invoke Set-ItemProperty -Times 1 -Exactly { $Value -eq 0 }
         }
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

   AfterAll {
      $env:TestRegistryPath = ''
   }
}
