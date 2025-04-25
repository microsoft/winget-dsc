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
      $expectedDSCResources = 'DeveloperMode', 'OsVersion', 'ShowSecondsInClock', 'EnableDarkMode', 'Taskbar', 'UserAccessControl', 'WindowsExplorer', 'EnableRemoteDesktop', 'EnableLongPathSupport', 'AdvancedNetworkSharingSetting'
      $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Developer).Name
      $availableDSCResources.length | Should -Be $expectedDSCResources.Count
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

# InModuleScope ensures that all mocks are on the Microsoft.Windows.Developer module.
InModuleScope Microsoft.Windows.Developer {
   Describe 'AdvancedNetworkSharingSetting' {
      BeforeAll {
         Mock Set-NetFirewallRule { }
      }

      It 'Get test for NetworkSettingName:<NetworkSettingName>, ExpectedEnabledProfiles:<ExpectedEnabledProfiles>' -ForEach @(
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $true; Profile = 'Private' }
            ExpectedEnabledProfiles = , 'Private'
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $false; Profile = 'Private' }
            ExpectedEnabledProfiles = @()
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $true; Profile = 'Private' }
            ExpectedEnabledProfiles = , 'Private'
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $false; Profile = 'Private' }
            ExpectedEnabledProfiles = @()
         }
      ) {
         Mock Get-NetFirewallRule { return $CurrentNetFirewallRules }

         $advancedNetworkSharingSettingSettingProvider = [AdvancedNetworkSharingSetting]@{
            Name     = $NetworkSettingName
            Profiles = , 'Private'
         }

         $getResourceResult = $advancedNetworkSharingSettingSettingProvider.Get()
         $getResourceResult.Name | Should -Be $NetworkSettingName
         $getResourceResult.Profiles | Should -Be $advancedNetworkSharingSettingSettingProvider.Profiles
         $getResourceResult.EnabledProfiles | Should -Be $ExpectedEnabledProfiles
      }

      It 'Test test for NetworkSettingName:<NetworkSettingName>, Profiles:<Profiles>, ExpectedValue:<ExpectedValue>' -ForEach @(
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            Profiles                = , 'Private'
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $true; Profile = 'Private' }
            ExpectedValue           = $true
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            Profiles                = @()
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $true; Profile = 'Private' }
            ExpectedValue           = $false
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            Profiles                = @()
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $false; Profile = 'Private' }
            ExpectedValue           = $true
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            Profiles                = , 'Private'
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $false; Profile = 'Private' }
            ExpectedValue           = $false
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            Profiles                = , 'Private'
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $true; Profile = 'Private' }
            ExpectedValue           = $true
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            Profiles                = @()
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $true; Profile = 'Private' }
            ExpectedValue           = $false
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            Profiles                = @()
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $false; Profile = 'Private' }
            ExpectedValue           = $true
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            Profiles                = , 'Private'
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $false; Profile = 'Private' }
            ExpectedValue           = $false
         }
      ) {
         Mock Get-NetFirewallRule { return $CurrentNetFirewallRules }

         $advancedNetworkSharingSettingSettingProvider = [AdvancedNetworkSharingSetting]@{
            Name     = $NetworkSettingName
            Profiles = $Profiles
         }

         $testResourceResult = $advancedNetworkSharingSettingSettingProvider.Test()
         $testResourceResult | Should -Be $ExpectedValue
      }

      It 'Set test for NetworkSettingName:<NetworkSettingName>, Profiles:<Profiles>, IsInTargetState:<IsInTargetState>' -ForEach @(
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            Profiles                = , 'Private'
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $true; Profile = 'Private' }
            IsInTargetState         = $true
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            Profiles                = @()
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $true; Profile = 'Private' }
            IsInTargetState         = $false
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            Profiles                = @()
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $false; Profile = 'Private' }
            IsInTargetState         = $true
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::NetworkDiscovery
            Profiles                = , 'Private'
            CurrentNetFirewallRules = @{Name = 'Network discovery'; Group = '@FirewallAPI.dll,-32752'; Enabled = $false; Profile = 'Private' }
            IsInTargetState         = $false
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            Profiles                = , 'Private'
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $true; Profile = 'Private' }
            IsInTargetState         = $true
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            Profiles                = @()
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $true; Profile = 'Private' }
            IsInTargetState         = $false
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            Profiles                = @()
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $false; Profile = 'Private' }
            IsInTargetState         = $true
         }
         @{ NetworkSettingName      = [AdvancedNetworkSharingSettingName]::FileAndPrinterSharing
            Profiles                = , 'Private'
            CurrentNetFirewallRules = @{Name = 'File and Printer Sharing'; Group = '@FirewallAPI.dll,-28502'; Enabled = $false; Profile = 'Private' }
            IsInTargetState         = $false
         }
      ) {
         Mock Get-NetFirewallRule { return $CurrentNetFirewallRules }

         $advancedNetworkSharingSettingSettingProvider = [AdvancedNetworkSharingSetting]@{
            Name     = $NetworkSettingName
            Profiles = $Profiles
         }

         $advancedNetworkSharingSettingSettingProvider.Set()
      }
   }
}

AfterAll {
   $env:TestRegistryPath = ''
}
