# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.Bluetooth

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.Bluetooth PowerShell module.
#>

BeforeAll {
    if ((Get-Module -ListAvailable -Name PSDesiredStateConfiguration -ErrorAction SilentlyContinue).Version -eq '2.0.7') {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }

    Import-Module Microsoft.Windows.Setting.Bluetooth -Force
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'USB', 'PenWindowsInk'
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Bluetooth).Name
        $availableDSCResources.Count | Should -Be 2
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'USB' {
    It 'Set connection notifications on' {
        $desiredState = @{
            ConnectionNotifications = $true
        }
        Invoke-DscResource -Name USB -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name USB -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.ConnectionNotifications | Should -Be $true
    }

    It 'Set slow charging notification off' {
        $desiredState = @{
            SlowChargingNotification = $false
        }
        Invoke-DscResource -Name USB -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name USB -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.SlowChargingNotification | Should -Be $false
    }

    It 'Set battery saver on' {
        $desiredState = @{
            BatterySaver = $true
        }
        Invoke-DscResource -Name USB -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name USB -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.BatterySaver | Should -Be $true
    }
}

Describe 'PenWindowsInk' {
    It 'Set finger tip font to SegoeUI' {
        $desiredState = @{
            FingerTipFont = 'SegoeUI'
        }
        Invoke-DscResource -Name PenWindowsInk -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name PenWindowsInk -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.FingerTipFont | Should -Be 'SegoeUI'
    }

    It 'Set write with your finger tip off' {
        $desiredState = @{
            WriteFingerTip = $false
        }
        Invoke-DscResource -Name PenWindowsInk -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name PenWindowsInk -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.WriteFingerTip | Should -Be $false
    }
}
