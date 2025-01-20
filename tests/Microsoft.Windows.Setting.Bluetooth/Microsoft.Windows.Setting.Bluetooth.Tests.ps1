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

    It 'Set primary button to right' {
        $desiredState = @{
            PrimaryButton = 'Right'
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.PrimaryButton | Should -Be 'Right'
    }

    It 'Set the pointer precision off' {
        $desiredState = @{
            PointerPrecision = $false
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.PointerPrecision | Should -Be $false
    }

    It 'Set the mouse scroll to single screen at time' {
        $desiredState = @{
            RollMouseScroll = $false
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.RollMouseScroll | Should -Be $false
        $finalState.LinesToScroll | Should -Be -1
    }

    It 'Set the mouse scroll length even lines to scroll are set to 5' {
        $desiredState = @{
            RollMouseScroll = $false
            LinesToScroll   = 5
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.LinesToScroll | Should -Be -1
    }

    It 'Set the mouse scroll length to 5' {
        $desiredState = @{
            RollMouseScroll = $true
            LinesToScroll   = 5
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.LinesToScroll | Should -Be 5
    }

    It 'Set the scroll inactive window' {
        $desiredState = @{
            ScrollInactiveWindows = $true
        }
        Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Mouse -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.ScrollInactiveWindows | Should -Be $true
    }

    It 'Set the scroll direction to up' {
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

Describe 'MobileDevice' {
    It 'Set mobile devices access to this PC' {
        $desiredState = @{
            AccessMobileDevice = $true
        }
        Invoke-DscResource -Name MobileDevice -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name MobileDevice -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.AccessMobileDevice | Should -Be $true
    }

    It 'Set Phone Link on' {
        $desiredState = @{
            PhoneLinkAccess = $true
        }
        Invoke-DscResource -Name MobileDevice -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name MobileDevice -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.PhoneLinkAccess | Should -Be $true
    }

    It 'Set the suggestion for mobile device to Windows' {
        $desiredState = @{
            ShowMobileDeviceSuggestions = $true
        }
        Invoke-DscResource -Name MobileDevice -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name MobileDevice -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.ShowMobileDeviceSuggestions | Should -Be $true
    }
}

Describe 'AutoPlay' {
    It 'Keeps current value.' {
        $initialState = Invoke-DscResource -Name AutoPlay -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}

        $parameters = @{ RemovableDriveDefault = 'KeepCurrentValue'; MemoryCardDefault = 'KeepCurrentValue' }

        $testResult = Invoke-DscResource -Name AutoPlay -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $true

        # Invoking set should not change these values.
        Invoke-DscResource -Name AutoPlay -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name AutoPlay -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.RemovableDriveDefault | Should -Be $initialState.RemovableDriveDefault
        $finalState.MemoryCardDefault | Should -Be $initialState.MemoryCardDefault
    }

    It 'Sets desired value for removable drive and memory card' {
        $desiredState = @{
            RemovableDriveDefault = 'MSTakeNoAction'
            MemoryCardDefault     = 'MSTakeNoAction'
        }

        Invoke-DscResource -Name AutoPlay -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name AutoPlay -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.RemovableDriveDefault | Should -Be 'MSTakeNoAction'
        $finalState.MemoryCardDefault | Should -Be 'MSTakeNoAction'
    }

    It 'Turns off auto play' {
        $desiredState = @{
            AutoPlay = $false
        }

        Invoke-DscResource -Name AutoPlay -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name AutoPlay -ModuleName Microsoft.Windows.Setting.Bluetooth -Method Get -Property @{}
        $finalState.AutoPlay | Should -Be $false
    }
}
