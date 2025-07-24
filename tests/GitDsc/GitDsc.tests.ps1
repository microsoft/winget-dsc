using module GitDsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the GitDsc PowerShell module.
#>

BeforeAll {
    Import-Module GitDsc -Force -ErrorAction SilentlyContinue
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'GitClone', 'GitRemote', 'GitConfigUserName', 'GitConfigUserEmail'
        $availableDSCResources = (Get-DscResource -Module GitDsc).Name
        $availableDSCResources.count | Should -Be 4
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'GitDsc' {
    It 'Clones a repository' {
        $desiredState = @{
            HttpsUrl      = 'https://github.com/microsoft/winget-dsc.git'
            RootDirectory = $env:TEMP
        }

        Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.HttpsUrl | Should -Be $desiredState.HttpsUrl
        $finalState.Ensure | Should -Be 'Present'
        $finalState.RootDirectory | Should -Be $desiredState.RootDirectory
    }

    It 'Clones a repository with a specific folder name' {
        $desiredState = @{
            HttpsUrl      = 'https://github.com/microsoft/winget-dsc.git'
            RootDirectory = $env:TEMP
            FolderName    = 'winget-dsc-clone-test'
        }

        Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.HttpsUrl | Should -Be $desiredState.HttpsUrl
        $finalState.Ensure | Should -Be 'Present'
        $finalState.RootDirectory | Should -Be $desiredState.RootDirectory
        $finalState.FolderName | Should -Be $desiredState.FolderName
    }

    It 'Should not clone a repository if an incorrect URL is provided' {
        $desiredState = @{
            HttpsUrl      = 'https://invalid-url.git'
            RootDirectory = $env:TEMP
        }

        { (Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState -ErrorAction Stop) } | Should -Throw 
    }
}
