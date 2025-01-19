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
        $expectedDSCResources = 'USB', 'PenWindowsInk', 'Mouse'
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Bluetooth).Name
        $availableDSCResources.Count | Should -Be 3
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

Describe 'Mouse' {
    BeforeAll {
        $class = [Mouse]::new() 

        $script:currentState = $class.Get()
        Write-Verbose -Message ('Current mouse settings') -Verbose
        Write-Verbose -Message ($script:currentState | ConvertTo-Json | Out-String) -Verbose
    }
    It 'Set cursor speed to 15' {
        $desiredState = @{
            CursorSpeed = 15
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.CursorSpeed | Should -Be 15
    }

    It 'Should throw error when cursor speed is higher than 20' {
        $desiredState = @{
            CursorSpeed = 21
        }
        { Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState } | Should -Throw
    }

    It 'Should set primary button to right' {
        $desiredState = @{
            PrimaryButton = 'Right'
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.PrimaryButton | Should -Be 'Right'
    }

    It 'Should set the pointer precision off' {
        $desiredState = @{
            PointerPrecision = $false
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.PointerPrecision | Should -Be $false
    }

    It 'Should set the mouse scroll to single screen at time' {
        $desiredState = @{
            RollMouseScroll = $false
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.RollMouseScroll | Should -Be $false
        $finalState.LinesToScroll | Should -Be -1
    }

    It 'Should set the mouse scroll length even lines to scroll are set to 5' {
        $desiredState = @{
            RollMouseScroll = $false 
            LinesToScroll   = 5
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.LinesToScroll | Should -Be -1
    }

    It 'Should set the mouse scroll length to 5' {
        $desiredState = @{
            RollMouseScroll = $true
            LinesToScroll   = 5
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.LinesToScroll | Should -Be 5
    }

    It 'Should set the scroll inactive window' {
        $desiredState = @{
            ScrollInactiveWindows = $true
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.ScrollInactiveWindows | Should -Be $true
    }

    It 'Should set the scroll direction to up' {
        $desiredState = @{
            ScrollDirection = 'Up'
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.ScrollDirection | Should -Be 'Up'
    }

    AfterAll {
        Write-Verbose -Message ('Restoring mouse settings to original state with') -Verbose
        Write-Verbose -Message ($script:currentState | ConvertTo-Json | Out-String) -Verbose
        $currentState.Set()
    }
}