# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.Privacy

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.Privacy PowerShell module.
#>

BeforeAll {
    $psDesiredStateModuleVersion = (Get-Module -ListAvailable -Name PSDesiredStateConfiguration).Version
    if ($null -eq $psDesiredStateModuleVersion) {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }

    Import-Module Microsoft.Windows.Setting.Privacy
    $params = @{
        EnablePersonalizedAds            = $true
        EnableLocalContentByLanguageList = $true
        EnableAppLaunchTracking          = $true
        ShowContentSuggestion            = $true
        EnableAccountNotifications       = $true
    }

    $currentState = Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Get -Property $params

    $global:Parameters = $currentState.ToHashTable()

    Write-Verbose ("Current state: `n{0}" -f $($global:Parameters | ConvertTo-Json | Out-String)) -Verbose
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'Privacy'
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Privacy).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'Privacy' {
    It 'Sets personalized ads' -Skip:(!$IsWindows) {
        $desiredState = @{
            EnablePersonalizedAds = $true
        }

        Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Get -Property $desiredState
        $finalState.EnablePersonalizedAds | Should -BeTrue
    }

    It 'Sets websites relevant content by access language list' -Skip:(!$IsWindows) {
        $desiredState = @{
            EnableLocalContentByLanguageList = $true
        }

        Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Get -Property $desiredState
        $finalState.EnableLocalContentByLanguageList | Should -BeTrue
    }

    It 'Sets improve start and search result by tracking app launches' -Skip:(!$IsWindows) {
        $desiredState = @{
            EnableAppLaunchTracking = $true
        }

        Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Get -Property $desiredState
        $finalState.EnableAppLaunchTracking | Should -BeTrue
    }

    It 'Sets suggestion content in settings app' -Skip:(!$IsWindows) {
        $desiredState = @{
            ShowContentSuggestion = $true
        }

        Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Get -Property $desiredState
        $finalState.ShowContentSuggestion | Should -BeTrue
    }

    It 'Sets the show notifications in settings app' -Skip:(!$IsWindows) {
        $desiredState = @{
            EnableAccountNotifications = $true
        }

        Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Get -Property $desiredState
        $finalState.EnableAccountNotifications | Should -BeTrue
    }
}

AfterAll {
    Write-Verbose -Message 'Restoring the machine to the original state.' -Verbose
    Invoke-DscResource -Name Privacy -ModuleName Microsoft.Windows.Setting.Privacy -Method Set -Property $global:Parameters
}
