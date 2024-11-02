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

InModuleScope -ModuleName GitDsc {
    Describe 'GitClone' {

        BeforeAll {
            Mock Assert-Git { return $true }
            Mock Invoke-GitClone -Verifiable

            $global:HttpsUrl = 'https://github.com/microsoft/winget-dsc.git'
            $global:TestGitRoot = Join-Path -Path $env:TEMP -ChildPath $(New-Guid)
        }

        $script:gitCloneResource = [GitClone]::new()
        Write-Output $gitCloneResource

        It 'New folder starts without cloned repo' {
            $gitCloneResource.HttpsUrl = $global:HttpsUrl
            $gitCloneResource.RootDirectory = $global:TestGitRoot
            $initialState = $gitCloneResource.Get()
            $initialState.Ensure | Should -Be 'Absent'
        }

        It 'Set throws when ensuring absent' {
            $gitCloneResource.Ensure = [Ensure]::Absent
            { $gitCloneResource.Set() } | Should -Throw
        }

        It 'Calls Invoke-GitClone when ensuring present' {
            $gitCloneResource.HttpsUrl = $global:HttpsUrl
            $gitCloneResource.RootDirectory = $global:TestGitRoot
            $gitCloneResource.Ensure = [Ensure]::Present
            # Run the setter
            { $gitCloneResource.Set() } | Should -Not -Throw
            # The setter should create the root directory if it doesn't exist
            Test-Path $global:TestGitRoot | Should -Be $true
            # Git clone should have been called once
            Assert-MockCalled Invoke-GitClone -Exactly 1
        }

        It 'Test should fail when remote does not match' {
            Mock Invoke-GitRemote { return 'https://github.com/Trenly/winget-dsc.git' }

            $gitCloneResource.HttpsUrl = $global:HttpsUrl
            $gitCloneResource.RootDirectory = $global:TestGitRoot
            $gitCloneResource.Ensure = [Ensure]::Present

            $gitCloneResource.Test() | Should -Be $false
        }

        It 'Test should succeed when remote matches' {
            # The folder has to be created here so that the DSC resource can attempt to fetch the remote from within it
            New-Item -ItemType Directory -Path $(Join-Path -Path $global:TestGitRoot -ChildPath 'winget-dsc') -Force

            Mock Invoke-GitRemote -Verifiable { return 'https://github.com/microsoft/winget-dsc.git' }

            $gitCloneResource.HttpsUrl = $global:HttpsUrl
            $gitCloneResource.RootDirectory = $global:TestGitRoot
            $gitCloneResource.Ensure = [Ensure]::Present

            $gitCloneResource.Test() | Should -Be $true
            Assert-MockCalled Invoke-GitRemote -Exactly 1
        }
    }
}

AfterAll {
    # Clean up cloned folder
    Remove-Item -Recurse -Force $global:TestGitRoot -ErrorAction 'SilentlyContinue'
}
