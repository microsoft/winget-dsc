# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.Time

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.Time PowerShell module.
#>

BeforeAll {
    if ($null -eq (Get-Module -ListAvailable -Name PSDesiredStateConfiguration))
    {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }
	
    $currentState = Invoke-DscResource -Name Time -ModuleName Microsoft.Windows.Setting.Time -Method Get -Property @{}
    $global:Parameters = $currentState.ToHashTable()
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "Time"
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Time).Name
        $availableDSCResources.Count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'Time' {
    It 'Display System Tray' {
        $desiredState = @{ ShowSystemTrayDateTime = $true }
      
        Invoke-DscResource -Name Time -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState
   
        $finalState = Invoke-DscResource -Name Time -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property $desiredState
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Hide System Tray' {
        $desiredState = @{ ShowSystemTrayDateTime = $false }
      
        Invoke-DscResource -Name Time -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState
   
        $finalState = Invoke-DscResource -Name Time -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property @{}
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Set Time Zone' {
        $desiredState = @{ TimeZone = "Pacific Standard Time" }
      
        Invoke-DscResource -Name Time -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $desiredState
   
        $finalState = Invoke-DscResource -Name Time -ModuleName Microsoft.Windows.Setting.Time -Method Test -Property @{}
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Set automatic updates to not synchronize' {
        $object = [Time]::new()
        $object.SetTimeZoneAutomatically = 'NoSync'

        # Set the state
        $object.Set()

        # Test the state
        $object.Test() | Should -Be $true
    }
}
AfterAll {
    # Restore the original state
    Write-Host -Object ("Restoring the original state")
    Invoke-DscResource -Name Time -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property $global:Parameters
}