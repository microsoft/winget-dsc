# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.WindowsUpdate

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.WindowsUpdate PowerShell module.
#>

BeforeAll {
    Import-Module Microsoft.Windows.Setting.WindowsUpdate

    $currentState = Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Get -Property @{}

    $global:Parameters = $currentState.GetParameters()

    Write-Verbose ("Current state: `n{0}" -f $($global:Parameters | ConvertTo-Json | Out-String)) -Verbose
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'WindowsUpdate'
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.WindowsUpdate).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'WindowsUpdate' {
    It 'Keeps current value.' {
        $initialState = Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Get -Property @{}

        $parameters = $initialState.GetParameters()

        $testResult = Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $true

        # Invoking set should not change these values.
        Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Get -Property @{}
        $finalState.IsContinuousInnovationOptedIn | Should -Be $initialState.IsContinuousInnovationOptedIn
        $finalState.AllowMUUpdateService | Should -Be $initialState.AllowMUUpdateService
        $finalState.IsExpedited | Should -Be $initialState.IsExpedited
        $finalState.AllowAutoWindowsUpdateDownloadOverMeteredNetwork | Should -Be $initialState.AllowAutoWindowsUpdateDownloadOverMeteredNetwork
        $finalState.RestartNotificationsAllowed | Should -Be $initialState.RestartNotificationsAllowed
        $finalState.SmartActiveHoursState | Should -Be $initialState.SmartActiveHoursState
        $finalstate.UserChoiceActiveHoursEnd | Should -Be $initialState.UserChoiceActiveHoursEnd
        $finalstate.UserChoiceActiveHoursStart | Should -Be $initialState.UserChoiceActiveHoursStart
        $finalState.DownloadMode | Should -Be $initialState.DownloadMode
        $finalState.DownloadRateBackgroundBps | Should -Be $initialState.DownloadRateBackgroundBps
        $finalState.DownloadRateForegroundBps | Should -Be $initialState.DownloadRateForegroundBps
        $finalstate.DownloadRateBackgroundPct | Should -Be $initialState.DownloadRateBackgroundPct
        $finalstate.DownloadRateForegroundPct | Should -Be $initialState.DownloadRateForegroundPct
        $finalState.UploadLimitGBMonth | Should -Be $initialState.UploadLimitGBMonth
        $finalState.UpRatePctBandwidth | Should -Be $initialState.UpRatePctBandwidth

    }

    It 'Sets desired value with only background' {
        $desiredState = @{
            IsContinuousInnovationOptedIn                    = $true
            AllowMUUpdateService                             = $true
            IsExpedited                                      = $true
            AllowAutoWindowsUpdateDownloadOverMeteredNetwork = $true
            RestartNotificationsAllowed                      = $true
            SmartActiveHoursState                            = 1
            UserChoiceActiveHoursEnd                         = 10
            UserChoiceActiveHoursStart                       = 2
            DownloadMode                                     = 1
            DownloadRateBackgroundBps                        = 100
            DownloadRateForegroundBps                        = 100
            UploadLimitGBMonth                               = 100
            UpRatePctBandwidth                               = 100
        }

        Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Get -Property @{}
        $finalState.IsContinuousInnovationOptedIn | Should -Be $desiredState.IsContinuousInnovationOptedIn
        $finalState.AllowMUUpdateService | Should -Be $desiredState.AllowMUUpdateService
        $finalState.IsExpedited | Should -Be $desiredState.IsExpedited
        $finalState.AllowAutoWindowsUpdateDownloadOverMeteredNetwork | Should -Be $desiredState.AllowAutoWindowsUpdateDownloadOverMeteredNetwork
        $finalState.RestartNotificationsAllowed | Should -Be $desiredState.RestartNotificationsAllowed
        $finalState.SmartActiveHoursState | Should -Be $desiredState.SmartActiveHoursState
        $finalstate.UserChoiceActiveHoursEnd | Should -Be $desiredState.UserChoiceActiveHoursEnd
        $finalstate.UserChoiceActiveHoursStart | Should -Be $desiredState.UserChoiceActiveHoursStart
        $finalState.DownloadMode | Should -Be $desiredState.DownloadMode
        $finalState.DownloadRateBackgroundBps | Should -Be $desiredState.DownloadRateBackgroundBps
        $finalState.DownloadRateForegroundBps | Should -Be $desiredState.DownloadRateForegroundBps
        $finalState.UploadLimitGBMonth | Should -Be $desiredState.UploadLimitGBMonth
        $finalState.UpRatePctBandwidth | Should -Be $desiredState.UpRatePctBandwidth
    }

    It 'Sets desired value with only background rate' {
        $desiredState = @{
            DownloadRateBackgroundPct = 50
            DownloadRateForegroundPct = 100
        }

        Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Get -Property @{}
        $finalState.DownloadRateBackgroundPct | Should -Be $desiredState.DownloadRateBackgroundPct
        $finalState.DownloadRateForegroundPct | Should -Be $desiredState.DownloadRateForegroundPct
    }
}

AfterAll {
    Write-Verbose -Message 'Restoring the machine to the original state.' -Verbose
    $global:Parameters.Remove('DownloadRateBackgroundPct')
    $global:Parameters.Remove('DownloadRateForegroundPct')
    Invoke-DscResource -Name WindowsUpdate -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Method Set -Property $global:Parameters
}
