# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Settings

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Settings PowerShell module.
#>

BeforeAll {
    if ($null -eq (Get-Module -ListAvailable -Name PSDesiredStateConfiguration)) {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }

    Import-Module Microsoft.Windows.Settings

    # Store original settings to restore after tests
    $script:originalSettings = @{}
    
    # Get current settings
    $currentSettings = [WindowsSettings]::new()
    $currentSettings.SID = 'TestSID'
    $currentState = $currentSettings.Get()
    
    $script:originalSettings.TaskbarAlignment = $currentState.TaskbarAlignment
    $script:originalSettings.AppColorMode = $currentState.AppColorMode
    $script:originalSettings.SystemColorMode = $currentState.SystemColorMode
    $script:originalSettings.DeveloperMode = $currentState.DeveloperMode
    $script:originalSettings.SetTimeZoneAutomatically = $currentState.SetTimeZoneAutomatically
    $script:originalSettings.TimeZone = $currentState.TimeZone
    $script:originalSettings.EnableTransparency = $currentState.EnableTransparency
    $script:originalSettings.ShowAccentColorOnStartAndTaskbar = $currentState.ShowAccentColorOnStartAndTaskbar
    $script:originalSettings.ShowAccentColorOnTitleBarsAndWindowBorders = $currentState.ShowAccentColorOnTitleBarsAndWindowBorders
    $script:originalSettings.AutoColorization = $currentState.AutoColorization
    $script:originalSettings.StartFolders = $currentState.StartFolders
    $script:originalSettings.ShowRecentList = $currentState.ShowRecentList
    $script:originalSettings.ShowRecommendedList = $currentState.ShowRecommendedList
    $script:originalSettings.TaskbarBadges = $currentState.TaskbarBadges
    $script:originalSettings.DesktopTaskbarBadges = $currentState.DesktopTaskbarBadges
    $script:originalSettings.TaskbarGroupingMode = $currentState.TaskbarGroupingMode
    $script:originalSettings.TaskbarMultiMon = $currentState.TaskbarMultiMon
    $script:originalSettings.DesktopTaskbarMultiMon = $currentState.DesktopTaskbarMultiMon
    $script:originalSettings.TaskbarMultiMonMode = $currentState.TaskbarMultiMonMode
    $script:originalSettings.DesktopTaskbarMultiMonMode = $currentState.DesktopTaskbarMultiMonMode
    $script:originalSettings.NotifyOnUsbErrors = $currentState.NotifyOnUsbErrors
    $script:originalSettings.NotifyOnWeakCharger = $currentState.NotifyOnWeakCharger
    
    Write-Host 'Original Settings captured:'
    Write-Host "  TaskbarAlignment: $($script:originalSettings.TaskbarAlignment)"
    Write-Host "  AppColorMode: $($script:originalSettings.AppColorMode)"
    Write-Host "  SystemColorMode: $($script:originalSettings.SystemColorMode)"
    Write-Host "  DeveloperMode: $($script:originalSettings.DeveloperMode)"
    Write-Host "  SetTimeZoneAutomatically: $($script:originalSettings.SetTimeZoneAutomatically)"
    Write-Host "  TimeZone: $($script:originalSettings.TimeZone)"
    Write-Host "  EnableTransparency: $($script:originalSettings.EnableTransparency)"
    Write-Host "  ShowAccentColorOnStartAndTaskbar: $($script:originalSettings.ShowAccentColorOnStartAndTaskbar)"
    Write-Host "  ShowAccentColorOnTitleBarsAndWindowBorders: $($script:originalSettings.ShowAccentColorOnTitleBarsAndWindowBorders)"
    Write-Host "  AutoColorization: $($script:originalSettings.AutoColorization)"
    Write-Host "  StartFolders: $($script:originalSettings.StartFolders -join ', ')"
    Write-Host "  ShowRecentList: $($script:originalSettings.ShowRecentList)"
    Write-Host "  ShowRecommendedList: $($script:originalSettings.ShowRecommendedList)"
    Write-Host "  TaskbarBadges: $($script:originalSettings.TaskbarBadges)"
    Write-Host "  DesktopTaskbarBadges: $($script:originalSettings.DesktopTaskbarBadges)"
    Write-Host "  TaskbarGroupingMode: $($script:originalSettings.TaskbarGroupingMode)"
    Write-Host "  TaskbarMultiMon: $($script:originalSettings.TaskbarMultiMon)"
    Write-Host "  DesktopTaskbarMultiMon: $($script:originalSettings.DesktopTaskbarMultiMon)"
    Write-Host "  TaskbarMultiMonMode: $($script:originalSettings.TaskbarMultiMonMode)"
    Write-Host "  DesktopTaskbarMultiMonMode: $($script:originalSettings.DesktopTaskbarMultiMonMode)"
    Write-Host "  NotifyOnUsbErrors: $($script:originalSettings.NotifyOnUsbErrors)"
    Write-Host "  NotifyOnWeakCharger: $($script:originalSettings.NotifyOnWeakCharger)"
}

AfterAll {
    # Restore original settings
    Write-Host 'Restoring original settings...'
    
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    $restoreSettings = [WindowsSettings]::new()
    $restoreSettings.SID = 'TestSID'
    
    # Restore user-level settings (don't require admin)
    if ($null -ne $script:originalSettings.TaskbarAlignment) {
        $restoreSettings.TaskbarAlignment = $script:originalSettings.TaskbarAlignment
    }
    if ($null -ne $script:originalSettings.AppColorMode) {
        $restoreSettings.AppColorMode = $script:originalSettings.AppColorMode
    }
    if ($null -ne $script:originalSettings.SystemColorMode) {
        $restoreSettings.SystemColorMode = $script:originalSettings.SystemColorMode
    }
    
    # Restore personalization settings (don't require admin)
    if ($null -ne $script:originalSettings.EnableTransparency) {
        $restoreSettings.EnableTransparency = $script:originalSettings.EnableTransparency
    }
    if ($null -ne $script:originalSettings.ShowAccentColorOnStartAndTaskbar) {
        $restoreSettings.ShowAccentColorOnStartAndTaskbar = $script:originalSettings.ShowAccentColorOnStartAndTaskbar
    }
    if ($null -ne $script:originalSettings.ShowAccentColorOnTitleBarsAndWindowBorders) {
        $restoreSettings.ShowAccentColorOnTitleBarsAndWindowBorders = $script:originalSettings.ShowAccentColorOnTitleBarsAndWindowBorders
    }
    if ($null -ne $script:originalSettings.AutoColorization) {
        $restoreSettings.AutoColorization = $script:originalSettings.AutoColorization
    }
    if ($null -ne $script:originalSettings.StartFolders -and $script:originalSettings.StartFolders.Count -gt 0) {
        $restoreSettings.StartFolders = $script:originalSettings.StartFolders
    }
    if ($null -ne $script:originalSettings.ShowRecentList) {
        $restoreSettings.ShowRecentList = $script:originalSettings.ShowRecentList
    }
    if ($null -ne $script:originalSettings.ShowRecommendedList) {
        $restoreSettings.ShowRecommendedList = $script:originalSettings.ShowRecommendedList
    }
    if ($null -ne $script:originalSettings.TaskbarBadges) {
        $restoreSettings.TaskbarBadges = $script:originalSettings.TaskbarBadges
    }
    if ($null -ne $script:originalSettings.DesktopTaskbarBadges) {
        $restoreSettings.DesktopTaskbarBadges = $script:originalSettings.DesktopTaskbarBadges
    }
    if (-not [string]::IsNullOrEmpty($script:originalSettings.TaskbarGroupingMode)) {
        $restoreSettings.TaskbarGroupingMode = $script:originalSettings.TaskbarGroupingMode
    }
    if ($null -ne $script:originalSettings.TaskbarMultiMon) {
        $restoreSettings.TaskbarMultiMon = $script:originalSettings.TaskbarMultiMon
    }
    if ($null -ne $script:originalSettings.DesktopTaskbarMultiMon) {
        $restoreSettings.DesktopTaskbarMultiMon = $script:originalSettings.DesktopTaskbarMultiMon
    }
    if (-not [string]::IsNullOrEmpty($script:originalSettings.TaskbarMultiMonMode)) {
        $restoreSettings.TaskbarMultiMonMode = $script:originalSettings.TaskbarMultiMonMode
    }
    if (-not [string]::IsNullOrEmpty($script:originalSettings.DesktopTaskbarMultiMonMode)) {
        $restoreSettings.DesktopTaskbarMultiMonMode = $script:originalSettings.DesktopTaskbarMultiMonMode
    }
    if ($null -ne $script:originalSettings.NotifyOnUsbErrors) {
        $restoreSettings.NotifyOnUsbErrors = $script:originalSettings.NotifyOnUsbErrors
    }
    if ($null -ne $script:originalSettings.NotifyOnWeakCharger) {
        $restoreSettings.NotifyOnWeakCharger = $script:originalSettings.NotifyOnWeakCharger
    }
    
    # Restore admin-level settings only if running as admin
    if ($isElevated) {
        if ($null -ne $script:originalSettings.DeveloperMode) {
            $restoreSettings.DeveloperMode = $script:originalSettings.DeveloperMode
        }
        if ($null -ne $script:originalSettings.SetTimeZoneAutomatically) {
            $restoreSettings.SetTimeZoneAutomatically = $script:originalSettings.SetTimeZoneAutomatically
        }
        if (-not [string]::IsNullOrEmpty($script:originalSettings.TimeZone)) {
            $restoreSettings.TimeZone = $script:originalSettings.TimeZone
        }
    }
    
    try {
        $restoreSettings.Set()
        Write-Host 'Settings restored successfully.'
    } catch {
        Write-Warning "Failed to restore some settings: $_"
    }
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = @('WindowsSettings')
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Settings).Name
        $availableDSCResources.Count | Should -Be $expectedDSCResources.Count
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'WindowsSettings - TaskbarAlignment' {
    It 'Gets current TaskbarAlignment' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.TaskbarAlignment | Should -BeIn @('Left', 'Center')
    }
    
    It 'Tests TaskbarAlignment when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.TaskbarAlignment = $currentState.TaskbarAlignment
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests TaskbarAlignment when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set opposite value
        $settings.TaskbarAlignment = ($currentState.TaskbarAlignment -eq 'Left') ? 'Center' : 'Left'
        
        $settings.Test() | Should -Be $false
    }
    
    It 'Sets TaskbarAlignment to Left' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarAlignment = 'Left'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarAlignment | Should -Be 'Left'
    }
    
    It 'Sets TaskbarAlignment to Center' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarAlignment = 'Center'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarAlignment | Should -Be 'Center'
    }
}

Describe 'WindowsSettings - ColorMode' {
    It 'Gets current AppColorMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.AppColorMode | Should -BeIn @('Light', 'Dark', 'Unknown')
    }
    
    It 'Gets current SystemColorMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.SystemColorMode | Should -BeIn @('Light', 'Dark', 'Unknown')
    }
    
    It 'Sets AppColorMode to Dark' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.AppColorMode = 'Dark'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.AppColorMode | Should -Be 'Dark'
    }
    
    It 'Sets AppColorMode to Light' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.AppColorMode = 'Light'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.AppColorMode | Should -Be 'Light'
    }
    
    It 'Sets SystemColorMode to Dark' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.SystemColorMode = 'Dark'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.SystemColorMode | Should -Be 'Dark'
    }
    
    It 'Sets SystemColorMode to Light' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.SystemColorMode = 'Light'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.SystemColorMode | Should -Be 'Light'
    }
    
    It 'Sets both AppColorMode and SystemColorMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.AppColorMode = 'Dark'
        $settings.SystemColorMode = 'Dark'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.AppColorMode | Should -Be 'Dark'
        $newState.SystemColorMode | Should -Be 'Dark'
    }
}

Describe 'WindowsSettings - DeveloperMode' {
    It 'Gets current DeveloperMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.DeveloperMode | Should -BeIn @($true, $false)
    }
    
    It 'Sets DeveloperMode to enabled' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DeveloperMode = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DeveloperMode | Should -Be $true
    }
    
    It 'Sets DeveloperMode to disabled' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DeveloperMode = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DeveloperMode | Should -Be $false
    }
    
    It 'Throws error when non-admin tries to set DeveloperMode' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isElevated) {
            Set-ItResult -Skipped -Because 'Test requires non-elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set to opposite value to force a change
        $settings.DeveloperMode = -not $currentState.DeveloperMode
        
        { $settings.Set() } | Should -Throw '*Administrator*'
    }
}

Describe 'WindowsSettings - TimeZone Settings' {
    It 'Gets current SetTimeZoneAutomatically' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Can be $true, $false, or $null (if registry key doesn't exist)
        $currentState.SetTimeZoneAutomatically | Should -BeIn @($true, $false, $null)
    }
    
    It 'Gets current TimeZone' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $availableTimeZones = Get-TimeZone -ListAvailable | Select-Object -ExpandProperty Id
        $currentState.TimeZone | Should -Not -BeNullOrEmpty
        $availableTimeZones | Should -Contain $currentState.TimeZone
    }
    
    It 'Sets SetTimeZoneAutomatically to enabled' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.SetTimeZoneAutomatically = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.SetTimeZoneAutomatically | Should -Be $true
    }
    
    It 'Sets SetTimeZoneAutomatically to disabled' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.SetTimeZoneAutomatically = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.SetTimeZoneAutomatically | Should -Be $false
    }
    
    It 'Sets TimeZone to Pacific Standard Time' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $testTimeZone1 = 'Pacific Standard Time'
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TimeZone = $testTimeZone1
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TimeZone | Should -Be $testTimeZone1
    }
    
    It 'Sets TimeZone to Eastern Standard Time' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $testTimeZone2 = 'Eastern Standard Time'
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TimeZone = $testTimeZone2
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TimeZone | Should -Be $testTimeZone2
    }
    
    It 'Throws error for invalid TimeZone' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TimeZone = 'Invalid TimeZone Name'
        
        { $settings.Set() } | Should -Throw '*Invalid TimeZone*'
    }
    
    It 'Throws error when non-admin tries to set SetTimeZoneAutomatically' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isElevated) {
            Set-ItResult -Skipped -Because 'Test requires non-elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set to opposite value to force a change (handle null case)
        $settings.SetTimeZoneAutomatically = -not ($currentState.SetTimeZoneAutomatically -eq $true)
        
        { $settings.Set() } | Should -Throw '*Administrator*'
    }
    
    It 'Throws error when non-admin tries to set TimeZone' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isElevated) {
            Set-ItResult -Skipped -Because 'Test requires non-elevated privileges'
            return
        }
        
        $testTimeZone1 = 'Pacific Standard Time'
        $testTimeZone2 = 'Eastern Standard Time'
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set to different timezone to force a change
        $settings.TimeZone = ($currentState.TimeZone -eq $testTimeZone1) ? $testTimeZone2 : $testTimeZone1
        
        { $settings.Set() } | Should -Throw '*Administrator*'
    }
    
    It 'Tests TimeZone when values match' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.TimeZone = $currentState.TimeZone
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests TimeZone when values differ' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $testTimeZone1 = 'Pacific Standard Time'
        $testTimeZone2 = 'Eastern Standard Time'
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set different timezone
        $differentTimeZone = ($currentState.TimeZone -eq $testTimeZone1) ? $testTimeZone2 : $testTimeZone1
        $settings.TimeZone = $differentTimeZone
        
        $settings.Test() | Should -Be $false
    }
}

Describe 'WindowsSettings - Combined Settings' {
    It 'Gets all settings at once' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.TaskbarAlignment | Should -Not -BeNullOrEmpty
        $currentState.AppColorMode | Should -Not -BeNullOrEmpty
        $currentState.SystemColorMode | Should -Not -BeNullOrEmpty
        $currentState.DeveloperMode | Should -BeIn @($true, $false)
        $currentState.SetTimeZoneAutomatically | Should -BeIn @($true, $false, $null)
        $currentState.TimeZone | Should -Not -BeNullOrEmpty
    }
    
    It 'Sets multiple user-level settings at once' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarAlignment = 'Left'
        $settings.AppColorMode = 'Dark'
        $settings.SystemColorMode = 'Dark'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarAlignment | Should -Be 'Left'
        $newState.AppColorMode | Should -Be 'Dark'
        $newState.SystemColorMode | Should -Be 'Dark'
    }
    
    It 'Sets all settings at once' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarAlignment = 'Center'
        $settings.AppColorMode = 'Light'
        $settings.SystemColorMode = 'Light'
        $settings.DeveloperMode = $false
        $settings.SetTimeZoneAutomatically = $false
        $settings.TimeZone = 'Pacific Standard Time'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarAlignment | Should -Be 'Center'
        $newState.AppColorMode | Should -Be 'Light'
        $newState.SystemColorMode | Should -Be 'Light'
        $newState.DeveloperMode | Should -Be $false
        $newState.SetTimeZoneAutomatically | Should -Be $false
        $newState.TimeZone | Should -Be 'Pacific Standard Time'
    }
    
    It 'Tests returns true when all settings match' {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            Set-ItResult -Skipped -Because 'Test requires elevated privileges'
            return
        }
        
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $settings.TaskbarAlignment = $currentState.TaskbarAlignment
        $settings.AppColorMode = $currentState.AppColorMode
        $settings.SystemColorMode = $currentState.SystemColorMode
        $settings.DeveloperMode = $currentState.DeveloperMode
        $settings.SetTimeZoneAutomatically = $currentState.SetTimeZoneAutomatically
        $settings.TimeZone = $currentState.TimeZone
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests returns false when any setting differs' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $settings.TaskbarAlignment = ($currentState.TaskbarAlignment -eq 'Left') ? 'Center' : 'Left'
        
        $settings.Test() | Should -Be $false
    }
}

Describe 'WindowsSettings - Null/Empty Properties' {
    It 'Test returns true when properties are null (not configured)' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        
        # Don't set any properties, they should default to null/empty
        $settings.Test() | Should -Be $true
    }
    
    It 'Ignores null properties during Set' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $beforeState = $settings.Get()
        
        # Create new instance with no properties set
        $settingsNull = [WindowsSettings]::new()
        $settingsNull.SID = 'TestSID'
        
        # This should not change anything
        $settingsNull.Set()
        
        $afterState = $settings.Get()
        
        # State should remain unchanged
        $afterState.TaskbarAlignment | Should -Be $beforeState.TaskbarAlignment
        $afterState.AppColorMode | Should -Be $beforeState.AppColorMode
        $afterState.SystemColorMode | Should -Be $beforeState.SystemColorMode
    }
}

Describe 'WindowsSettings - Personalization Colors' {
    It 'Gets current EnableTransparency' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.EnableTransparency | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets EnableTransparency to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.EnableTransparency = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.EnableTransparency | Should -Be $true
    }
    
    It 'Sets EnableTransparency to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.EnableTransparency = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.EnableTransparency | Should -Be $false
    }
    
    It 'Gets current ShowAccentColorOnStartAndTaskbar' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.ShowAccentColorOnStartAndTaskbar | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets ShowAccentColorOnStartAndTaskbar to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.ShowAccentColorOnStartAndTaskbar = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.ShowAccentColorOnStartAndTaskbar | Should -Be $true
    }
    
    It 'Sets ShowAccentColorOnStartAndTaskbar to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.ShowAccentColorOnStartAndTaskbar = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.ShowAccentColorOnStartAndTaskbar | Should -Be $false
    }
    
    It 'Gets current ShowAccentColorOnTitleBarsAndWindowBorders' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.ShowAccentColorOnTitleBarsAndWindowBorders | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets ShowAccentColorOnTitleBarsAndWindowBorders to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.ShowAccentColorOnTitleBarsAndWindowBorders = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.ShowAccentColorOnTitleBarsAndWindowBorders | Should -Be $true
    }
    
    It 'Sets ShowAccentColorOnTitleBarsAndWindowBorders to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.ShowAccentColorOnTitleBarsAndWindowBorders = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.ShowAccentColorOnTitleBarsAndWindowBorders | Should -Be $false
    }
    
    It 'Gets current AutoColorization' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.AutoColorization | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets AutoColorization to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.AutoColorization = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.AutoColorization | Should -Be $true
    }
    
    It 'Sets AutoColorization to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.AutoColorization = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.AutoColorization | Should -Be $false
    }
}

Describe 'WindowsSettings - Start Folders' {
    It 'Gets current StartFolders' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()

        if ($currentState.StartFolders -eq $null -or $currentState.StartFolders.Count -eq 0) {
            Set-ItResult -Skipped -Because 'No StartFolders configured to test'
            return
        }
        
        $folders = [array]$currentState.StartFolders
        $folders | Should -Not -BeNullOrEmpty
        { $folders.Count } | Should -Not -Throw
    }
    
    It 'Sets StartFolders to Documents and Downloads' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.StartFolders = @('Documents', 'Downloads')
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.StartFolders | Should -Contain 'Documents'
        $newState.StartFolders | Should -Contain 'Downloads'
    }
    
    It 'Sets StartFolders to Settings and Explorer' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.StartFolders = @('Settings', 'Explorer')
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.StartFolders | Should -Contain 'Settings'
        $newState.StartFolders | Should -Contain 'Explorer'
    }
    
    It 'Throws error for invalid StartFolder name' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.StartFolders = @('InvalidFolder')
        
        { $settings.Set() } | Should -Throw '*Invalid Start folder name*'
    }
    
    It 'Tests StartFolders when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.StartFolders = $currentState.StartFolders
        
        $settings.Test() | Should -Be $true
    }
}

Describe 'WindowsSettings - ShowRecentList' {
    It 'Gets current ShowRecentList' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be either $true, $false, or $null
        $currentState.ShowRecentList | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets ShowRecentList to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.ShowRecentList = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.ShowRecentList | Should -Be $true
    }
    
    It 'Sets ShowRecentList to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.ShowRecentList = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.ShowRecentList | Should -Be $false
    }
    
    It 'Tests ShowRecentList when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.ShowRecentList = $currentState.ShowRecentList
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests ShowRecentList when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set opposite value
        $settings.ShowRecentList = -not $currentState.ShowRecentList
        
        $settings.Test() | Should -Be $false
    }
}

Describe 'WindowsSettings - ShowRecommendedList' {
    It 'Gets current ShowRecommendedList' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.ShowRecommendedList | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets ShowRecommendedList to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.ShowRecommendedList = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.ShowRecommendedList | Should -Be $true
    }
    
    It 'Sets ShowRecommendedList to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.ShowRecommendedList = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.ShowRecommendedList | Should -Be $false
    }
    
    It 'Tests ShowRecommendedList when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.ShowRecommendedList = $currentState.ShowRecommendedList
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests ShowRecommendedList when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set opposite value
        $settings.ShowRecommendedList = -not $currentState.ShowRecommendedList
        
        $settings.Test() | Should -Be $false
    }
}

Describe 'WindowsSettings - TaskbarBadges' {
    It 'Gets current TaskbarBadges' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $currentState.TaskbarBadges | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets TaskbarBadges to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarBadges = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarBadges | Should -Be $true
    }
    
    It 'Sets TaskbarBadges to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarBadges = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarBadges | Should -Be $false
    }
    
    It 'Tests TaskbarBadges when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.TaskbarBadges = $currentState.TaskbarBadges
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests TaskbarBadges when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set opposite value
        $settings.TaskbarBadges = -not $currentState.TaskbarBadges
        
        $settings.Test() | Should -Be $false
    }
}

Describe 'WindowsSettings - DesktopTaskbarBadges' {
    It 'Gets current DesktopTaskbarBadges' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be either $true, $false, or $null
        $currentState.DesktopTaskbarBadges | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets DesktopTaskbarBadges to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DesktopTaskbarBadges = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DesktopTaskbarBadges | Should -Be $true
    }
    
    It 'Sets DesktopTaskbarBadges to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DesktopTaskbarBadges = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DesktopTaskbarBadges | Should -Be $false
    }
    
    It 'Tests DesktopTaskbarBadges when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.DesktopTaskbarBadges = $currentState.DesktopTaskbarBadges
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests DesktopTaskbarBadges when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set opposite value
        $settings.DesktopTaskbarBadges = -not $currentState.DesktopTaskbarBadges
        
        $settings.Test() | Should -Be $false
    }
}

Describe 'WindowsSettings - TaskbarGroupingMode' {
    It 'Gets current TaskbarGroupingMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be either Always, WhenFull, Never, or null
        $currentState.TaskbarGroupingMode | Should -BeIn @('Always', 'WhenFull', 'Never', $null)
    }
    
    It 'Sets TaskbarGroupingMode to Always' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarGroupingMode = 'Always'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarGroupingMode | Should -Be 'Always'
    }
    
    It 'Sets TaskbarGroupingMode to WhenFull' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarGroupingMode = 'WhenFull'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarGroupingMode | Should -Be 'WhenFull'
    }
    
    It 'Sets TaskbarGroupingMode to Never' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarGroupingMode = 'Never'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarGroupingMode | Should -Be 'Never'
    }
    
    It 'Tests TaskbarGroupingMode when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.TaskbarGroupingMode = $currentState.TaskbarGroupingMode
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Throws error for invalid TaskbarGroupingMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarGroupingMode = 'InvalidValue'
        
        { $settings.Set() } | Should -Throw '*Invalid TaskbarGroupingMode*'
    }
}

Describe 'WindowsSettings - TaskbarMultiMon' {
    It 'Gets current TaskbarMultiMon' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be either $true, $false, or $null
        $currentState.TaskbarMultiMon | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets TaskbarMultiMon to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarMultiMon = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarMultiMon | Should -Be $true
    }
    
    It 'Sets TaskbarMultiMon to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarMultiMon = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarMultiMon | Should -Be $false
    }
    
    It 'Tests TaskbarMultiMon when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.TaskbarMultiMon = $currentState.TaskbarMultiMon
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests TaskbarMultiMon when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set opposite value
        $settings.TaskbarMultiMon = -not $currentState.TaskbarMultiMon
        
        $settings.Test() | Should -Be $false
    }
}

Describe 'WindowsSettings - DesktopTaskbarMultiMon' {
    It 'Gets current DesktopTaskbarMultiMon' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be either $true, $false, or $null
        $currentState.DesktopTaskbarMultiMon | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets DesktopTaskbarMultiMon to enabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DesktopTaskbarMultiMon = $true
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DesktopTaskbarMultiMon | Should -Be $true
    }
    
    It 'Sets DesktopTaskbarMultiMon to disabled' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DesktopTaskbarMultiMon = $false
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DesktopTaskbarMultiMon | Should -Be $false
    }
    
    It 'Tests DesktopTaskbarMultiMon when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.DesktopTaskbarMultiMon = $currentState.DesktopTaskbarMultiMon
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests DesktopTaskbarMultiMon when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set opposite value
        $settings.DesktopTaskbarMultiMon = -not $currentState.DesktopTaskbarMultiMon
        
        $settings.Test() | Should -Be $false
    }
}

Describe 'WindowsSettings - TaskbarMultiMonMode' {
    It 'Gets current TaskbarMultiMonMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be one of the valid values or null
        $currentState.TaskbarMultiMonMode | Should -BeIn @('Duplicate', 'PrimaryAndWindow', 'WindowOnly', $null)
    }
    
    It 'Sets TaskbarMultiMonMode to Duplicate' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarMultiMonMode = 'Duplicate'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarMultiMonMode | Should -Be 'Duplicate'
    }
    
    It 'Sets TaskbarMultiMonMode to PrimaryAndWindow' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarMultiMonMode = 'PrimaryAndWindow'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarMultiMonMode | Should -Be 'PrimaryAndWindow'
    }
    
    It 'Sets TaskbarMultiMonMode to WindowOnly' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarMultiMonMode = 'WindowOnly'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.TaskbarMultiMonMode | Should -Be 'WindowOnly'
    }
    
    It 'Tests TaskbarMultiMonMode when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        
        # First set a known value
        $settings.TaskbarMultiMonMode = 'Duplicate'
        $settings.Set()
        
        # Now test with same value
        $testSettings = [WindowsSettings]::new()
        $testSettings.SID = 'TestSID'
        $testSettings.TaskbarMultiMonMode = 'Duplicate'
        
        $testSettings.Test() | Should -Be $true
    }
    
    It 'Tests TaskbarMultiMonMode when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        
        # First set a known value
        $settings.TaskbarMultiMonMode = 'Duplicate'
        $settings.Set()
        
        # Now test with different value
        $testSettings = [WindowsSettings]::new()
        $testSettings.SID = 'TestSID'
        $testSettings.TaskbarMultiMonMode = 'WindowOnly'
        
        $testSettings.Test() | Should -Be $false
    }
    
    It 'Throws error for invalid TaskbarMultiMonMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.TaskbarMultiMonMode = 'InvalidValue'
        
        { $settings.Set() } | Should -Throw '*Invalid TaskbarMultiMonMode*'
    }
}

Describe 'WindowsSettings - DesktopTaskbarMultiMonMode' {
    It 'Gets current DesktopTaskbarMultiMonMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be one of the valid values or null
        $currentState.DesktopTaskbarMultiMonMode | Should -BeIn @('Duplicate', 'PrimaryAndWindow', 'WindowOnly', $null)
    }
    
    It 'Sets DesktopTaskbarMultiMonMode to Duplicate' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DesktopTaskbarMultiMonMode = 'Duplicate'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DesktopTaskbarMultiMonMode | Should -Be 'Duplicate'
    }
    
    It 'Sets DesktopTaskbarMultiMonMode to PrimaryAndWindow' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DesktopTaskbarMultiMonMode = 'PrimaryAndWindow'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DesktopTaskbarMultiMonMode | Should -Be 'PrimaryAndWindow'
    }
    
    It 'Sets DesktopTaskbarMultiMonMode to WindowOnly' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DesktopTaskbarMultiMonMode = 'WindowOnly'
        
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.DesktopTaskbarMultiMonMode | Should -Be 'WindowOnly'
    }
    
    It 'Tests DesktopTaskbarMultiMonMode when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        
        $settings.DesktopTaskbarMultiMonMode = 'Duplicate'
        $settings.Set()
        
        $testSettings = [WindowsSettings]::new()
        $testSettings.SID = 'TestSID'
        $testSettings.DesktopTaskbarMultiMonMode = 'Duplicate'
        
        $testSettings.Test() | Should -Be $true
    }
    
    It 'Tests DesktopTaskbarMultiMonMode when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        
        $settings.DesktopTaskbarMultiMonMode = 'Duplicate'
        $settings.Set()
        
        $testSettings = [WindowsSettings]::new()
        $testSettings.SID = 'TestSID'
        $testSettings.DesktopTaskbarMultiMonMode = 'WindowOnly'
        
        $testSettings.Test() | Should -Be $false
    }
    
    It 'Throws error for invalid DesktopTaskbarMultiMonMode' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $settings.DesktopTaskbarMultiMonMode = 'InvalidValue'
        
        { $settings.Set() } | Should -Throw '*Invalid DesktopTaskbarMultiMonMode*'
    }
}

Describe 'WindowsSettings - USB' {
    It 'Gets current NotifyOnUsbErrors' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be either $true, $false, or $null
        $currentState.NotifyOnUsbErrors | Should -BeIn @($true, $false, $null)
    }
    
    It 'Gets current NotifyOnWeakCharger' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Should be either $true, $false, or $null
        $currentState.NotifyOnWeakCharger | Should -BeIn @($true, $false, $null)
    }
    
    It 'Sets NotifyOnUsbErrors to true' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $settings.NotifyOnUsbErrors = -not $currentState.NotifyOnUsbErrors
        
        $settings.Test() | Should -Be $false
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.NotifyOnUsbErrors | Should -Be $settings.NotifyOnUsbErrors
    }
    
    It 'Sets NotifyOnWeakCharger to true' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        $settings.NotifyOnWeakCharger = -not $currentState.NotifyOnWeakCharger
        
        $settings.Test() | Should -Be $false
        $settings.Set()
        
        $newState = $settings.Get()
        $newState.NotifyOnWeakCharger | Should -Be $settings.NotifyOnWeakCharger
    }
    
    It 'Tests NotifyOnUsbErrors when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.NotifyOnUsbErrors = $currentState.NotifyOnUsbErrors
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests NotifyOnWeakCharger when values match' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        $settings.NotifyOnWeakCharger = $currentState.NotifyOnWeakCharger
        
        $settings.Test() | Should -Be $true
    }
    
    It 'Tests USB settings when values differ' {
        $settings = [WindowsSettings]::new()
        $settings.SID = 'TestSID'
        $currentState = $settings.Get()
        
        # Set opposite values
        $settings.NotifyOnUsbErrors = -not $currentState.NotifyOnUsbErrors
        $settings.NotifyOnWeakCharger = -not $currentState.NotifyOnWeakCharger
        
        $settings.Test() | Should -Be $false
    }
}