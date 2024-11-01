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
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'GitClone', 'GitRemote', 'GitConfigUserName', 'GitConfigUserEmail'
        $availableDSCResources = (Get-DscResource -Module GitDsc).Name
        $availableDSCResources.count | Should -Be 4
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}


AfterAll {
    # Clean up cloned folder
}