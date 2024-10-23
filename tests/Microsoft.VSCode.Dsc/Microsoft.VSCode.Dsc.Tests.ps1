# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.VSCode.Dsc

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.VSCode.Dsc PowerShell module.
#>

BeforeAll {
    Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    Import-Module Microsoft.VSCode.Dsc
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "VSCodeExtension", "VSCodeInstaller"
        $availableDSCResources = (Get-DscResource -Module Microsoft.VSCode.Dsc).Name
        $availableDSCResources.count | Should -Be 2
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'VSCodeInstaller' {
    It 'Installs Visual Studio Code Insiders successfully.' -Skip:(!$IsWindows) {
        $parameters = @{
            Insiders = $true
        }

        Invoke-DscResource -Name VSCodeInstaller -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $parameters

        $finalState = Invoke-DscResource -Name VSCodeInstaller -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $parameters
        $finalState.Path | Should -NotBeNullOrEmpty
        $finalState.Exist | Should -BeTrue
        $finalState.Insiders | Should -BeTrue
    }

    It 'Installs Visual Studio Code with version successfully.' -Skip:(!$IsWindows) {
        $parameters = @{
            Version = '1.94.1'
        }

        Invoke-DscResource -Name VSCodeInstaller -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $parameters

        $finalState = Invoke-DscResource -Name VSCodeInstaller -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $parameters
        $finalState.Path | Should -NotBeNullOrEmpty
        $finalState.Exist | Should -BeTrue
        $finalState.Version | Should -Be $parameters.Version
    }
}

Describe 'VSCodeExtension' {
    It 'Sets desired extension' -Skip:(!$IsWindows) {
        $desiredState = @{
            Name = 'ms-azure-devops.azure-pipelines'
        }
        
        Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $desiredState
     
        $finalState = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be $desiredState.Name
        $finalState.Exist | Should -BeTrue
     }
}

Describe 'VSCodeExtension-Insiders' {
    It 'Sets desired extension in Insiders edition' -Skip:(!$IsWindows) {
        $desiredState = @{
            Name = 'ms-azure-devops.azure-pipelines'
            Insiders = $true
        }
        
        Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $desiredState
     
        $finalState = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be $desiredState.Name
        $finalState.Exist | Should -BeTrue
     }
}

Describe "VSCodeInstaller" {
    # It 'Uninstalls Visual Studio Code successfully.' -Skip:(!$IsWindows) {
    #     $parameters = @{
    #         Exist = $false
    #     }

    #     Invoke-DscResource -Name VSCodeInstaller -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $parameters

    #     $finalState = Invoke-DscResource -Name VSCodeInstaller -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $parameters
    #     $finalState.Path | Should -BeNullOrEmpty
    #     $finalState.Exist | Should -BeFalse
    # }

    # It 'Uninstalls Visual Studio Code Insiders successfully.' -Skip:(!$IsWindows) {
    #     $parameters = @{
    #         Exist = $false
    #     }

    #     Invoke-DscResource -Name VSCodeInstaller -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $parameters

    #     $finalState = Invoke-DscResource -Name VSCodeInstaller -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $parameters
    #     $finalState.Path | Should -BeNullOrEmpty
    #     $finalState.Exist | Should -BeFalse
    # }
}