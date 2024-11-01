# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module GitDsc

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the GitDsc PowerShell module.
#>

BeforeAll {
    if ($null -eq (Get-Module -ListAvailable -Name PSDesiredStateConfiguration))
    {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }
	
    Import-Module GitDsc

    # Create test folder for cloning into
    $global:TestGitRoot = Join-Path -Path $env:TEMP -ChildPath $(New-Guid)
    New-Item -ItemType Directory -Path $global:TestGitRoot -Force
    $global:HttpsUrl = 'https://github.com/microsoft/winget-dsc.git'
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'GitClone', 'GitRemote', 'GitConfigUserName', 'GitConfigUserEmail'
        $availableDSCResources = (Get-DscResource -Module GitDsc).Name
        $availableDSCResources.count | Should -Be 4
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'GitClone' {
    It 'New folder starts without cloned repo' {
        $initialState = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property @{
            HttpsUrl      = $global:HttpsUrl
            RootDirectory = $global:TestGitRoot
        }
        $initialState.Ensure | Should -Be 'Absent'
    }

    It 'Able to clone repo' {
        $desiredState = @{HttpsUrl = $global:HttpsUrl; RootDirectory = $global:TestGitRoot }
        Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Set -Property $desiredState
        $finalState = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.Ensure | Should -Be 'Present'
        $testResult = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Test -Property $desiredState
        $testResult.InDesiredState | Should -Be $true
    }
}

AfterAll {
    # Clean up cloned folder
    Remove-Item -Recurse -Force $global:TestGitRoot
}