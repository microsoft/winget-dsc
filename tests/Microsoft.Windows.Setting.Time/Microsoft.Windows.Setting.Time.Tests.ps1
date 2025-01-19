# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.Time

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.Time PowerShell module.
#>

BeforeAll {
    if ($null -eq (Get-Module -ListAvailable -Name PSDesiredStateConfiguration)) {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }

    $timeZoneState = Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Get -Property @{}
    $global:timeZoneParameters = $timeZoneState.ToHashTable()

    $clockState = Invoke-DscResource -Name Clock -ModuleName Microsoft.Windows.Setting.Time -Method Get -Property @{}
    $global:clockStateParameters = $clockState.ToHashTable()
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'TimeZone', 'Clock'
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Time).Name
        $availableDSCResources.Count | Should -Be 2
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'TimeZone' {
    It 'Set Time Zone only by Id' {
        $desiredState = @{ Id = 'Pacific Standard Time' }

        Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property @{}
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Set Time Zone automatically' {
        $desiredState = @{ Id = 'W. Europe Standard Time'; SetTimeZoneAutomatically = $true }

        Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property @{}
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Disable Time automatically' {
        $desiredState = @{ Id = 'W. Europe Standard Time'; SetTimeAutomatically = $false }

        Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property @{}
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Disable daylight saving' {
        $desiredState = @{
            Id                       = (Get-TimeZone -ListAvailable | Where-Object { $_.SupportsDaylightSavingTime -eq $true } | Select-Object -First 1 -ExpandProperty Id)
            SetTimeZoneAutomatically = $false
            AdjustForDaylightSaving  = $false
        }

        Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property @{}
        $finalState.InDesiredState | Should -Be $true
    }
}

Describe 'Clock' {
    It 'Display System Tray' {
        $desiredState = @{ ShowSystemTrayDateTime = $true }

        Invoke-DscResource -Name Clock -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Clock -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property $desiredState
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Hide System Tray' {
        $desiredState = @{ ShowSystemTrayDateTime = $false }

        Invoke-DscResource -Name Clock -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Clock -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property @{}
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Disable clock notify change' {
        $desiredState = @{ NotifyClockChange = $false }

        Invoke-DscResource -Name Clock -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Clock -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property @{}
        $finalState.InDesiredState | Should -Be $true
    }
}

AfterAll {
    # Restore the original state
    Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $global:timeZoneParameters
    Invoke-DscResource -Name Clock -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $global:clockStateParameters
}
