
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.Personalization

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.Personalization PowerShell module.
#>

BeforeAll {
    if ((Get-Module -ListAvailable -Name PSDesiredStateConfiguration -ErrorAction SilentlyContinue).Version -eq '2.0.7') {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }

    Import-Module Microsoft.Windows.Setting.Personalization -Force

    $script:currentSettings = [BackgroundPicture]::GetCurrentState()

    Write-Verbose -Message 'Current settings:' -Verbose
    Write-Verbose -Message ($currentSettings | ConvertTo-Json | Out-String) -Verbose

    # TODO: Create picture bundle in repo to test each use case
    $script:defaultPicturePath = Join-Path $env:windir 'Web' 'Wallpaper' 'Windows'
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'BackgroundPicture', 'BackgroundSolidColor', 'BackgroundWindowsSpotlight'
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Personalization).Name
        $availableDSCResources.length | Should -Be 3
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'BackgroundPicture' {
    It 'Sets the background picture' {
        $picture = Get-ChildItem -Path $defaultPicturePath -Filter *.jpg | Select-Object -First 1
        Write-Verbose -Message "Using picture: $($picture.FullName)" -Verbose

        $property = @{
            Picture = $picture.FullName
        }

        Invoke-DscResource -Name BackgroundPicture -ModuleName Microsoft.Windows.Setting.Personalization -Method Set -Property $property

        $finalState = Invoke-DscResource -Name BackgroundPicture -ModuleName Microsoft.Windows.Setting.Personalization -Method Get -Property $property
        $finalState.Picture | Should -Be $property.Picture
    }

    It 'Sets the background color if centering the picture' {
        $picture = Get-ChildItem -Path $defaultPicturePath -Filter *.jpg | Select-Object -First 1
        Write-Verbose -Message "Using picture: $($picture.FullName)" -Verbose

        $property = @{
            Picture         = $picture.FullName
            Style           = 'Center'
            BackgroundColor = '0,0,0'
        }

        Invoke-DscResource -Name BackgroundPicture -ModuleName Microsoft.Windows.Setting.Personalization -Method Set -Property $property

        $finalState = Invoke-DscResource -Name BackgroundPicture -ModuleName Microsoft.Windows.Setting.Personalization -Method Get -Property $property
        $finalState.BackgroundColor | Should -Be $property.BackgroundColor
        $finalState.Style | Should -Be $property.Fit
        $finalState.Picture | Should -Not -BeNullOrEmpty
    }
}

Describe 'BackgroundSolidColor' {
    It 'Sets the background color' {
        $property = @{
            BackgroundColor = '0,128,0' # Green
        }

        Invoke-DscResource -Name BackgroundSolidColor -ModuleName Microsoft.Windows.Setting.Personalization -Method Set -Property $property

        $finalState = Invoke-DscResource -Name BackgroundSolidColor -ModuleName Microsoft.Windows.Setting.Personalization -Method Get -Property $property
        $finalState.BackgroundColor | Should -Be $property.BackgroundColor
    }
}

Describe 'BackgroundWindowsSpotlight' {
    It 'Sets the background to Windows Spotlight' {
        $property = @{
            EnableWindowsSpotlight = $true
        }

        Invoke-DscResource -Name BackgroundWindowsSpotlight -ModuleName Microsoft.Windows.Setting.Personalization -Method Set -Property $property

        $finalState = Invoke-DscResource -Name BackgroundWindowsSpotlight -ModuleName Microsoft.Windows.Setting.Personalization -Method Get -Property $property
        $finalState.WindowsSpotlight | Should -Be $property.WindowsSpotlight
    }

    It 'Disables the background to Windows Spotlight' {
        $property = @{
            EnableWindowsSpotlight = $false
        }

        Invoke-DscResource -Name BackgroundWindowsSpotlight -ModuleName Microsoft.Windows.Setting.Personalization -Method Set -Property $property

        $finalState = Invoke-DscResource -Name BackgroundWindowsSpotlight -ModuleName Microsoft.Windows.Setting.Personalization -Method Get -Property $property
        $finalState.WindowsSpotlight | Should -Be $property.WindowsSpotlight
    }
}

AfterAll {
    Write-Verbose -Message 'Restoring settings:' -Verbose
    Write-Verbose -Message ($currentSettings | ConvertTo-Json | Out-String) -Verbose
    Invoke-DscResource -Name BackgroundPicture -ModuleName Microsoft.Windows.Setting.Personalization -Method Set -Property $currentSettings.ToHashTable()
}
