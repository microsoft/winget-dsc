using module GitDsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the GitDsc PowerShell module.
#>

BeforeAll {
    if ((Get-Module -Name PSDesiredStateConfiguration -ListAvailable).Version -ne '2.0.7') {
        Write-Verbose -Message 'Installing PSDesiredStateConfiguration module.' -Verbose
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck -RequiredVersion '2.0.7'
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

    It 'Clones a repository without checkout and file contents' {
        $desiredState = @{
            HttpsUrl      = 'https://github.com/microsoft/winget-dsc.git'
            RootDirectory = $env:TEMP
            ExtraArgs     = '--filter=blob:none --no-checkout'
        }

        Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.HttpsUrl | Should -Be $desiredState.HttpsUrl
        $finalState.Ensure | Should -Be 'Present'
        $finalState.RootDirectory | Should -Be $desiredState.RootDirectory
    }

    It 'Should not clone a repository if an incorrect URL is provided' {
        $desiredState = @{
            HttpsUrl      = 'https://invalid-url.git'
            RootDirectory = $env:TEMP
        }

        { (Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState -ErrorAction Stop) } | Should -Throw 
    }
}
