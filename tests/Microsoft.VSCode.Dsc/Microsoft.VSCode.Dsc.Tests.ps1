# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.VSCode.Dsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.VSCode.Dsc PowerShell module.
#>

BeforeAll {
    Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    Import-Module Microsoft.VSCode.Dsc

    # Install VSCode
    Invoke-WebRequest https://raw.githubusercontent.com/PowerShell/vscode-powershell/main/scripts/Install-VSCode.ps1 -UseBasicParsing -OutFile Install-VSCode.ps1
    .\Install-VSCode.ps1 -BuildEdition Stable-User -Confirm:$false

    # Install VSCode Insiders
    .\Install-VSCode.ps1 -BuildEdition Insider-User -Confirm:$false
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'VSCodeExtension'
        $availableDSCResources = (Get-DscResource -Module Microsoft.VSCode.Dsc).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'VSCodeExtension' {
    It 'Keeps current extension.' -Skip:(!$IsWindows) {
        $parameters = @{
            Name = 'ms-vscode.powershell'
        }
        $initialState = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $parameters

        $testResult = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $true

        # Invoking set should not change these values.
        Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $parameters
        $finalState.Name | Should -Be $initialState.Name
        $finalState.Version | Should -Be $initialState.Version
        $finalState.Exist | Should -Be $initialState.Exist
    }

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
    It 'Keeps current extension in Insiders edition.' -Skip:(!$IsWindows) {
        $parameters = @{
            Name     = 'ms-vscode.powershell'
            Insiders = $true
        }

        $initialState = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $parameters

        $testResult = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Test -Property $parameters
        $testResult.InDesiredState | Should -Be $true

        # Invoking set should not change these values.
        Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $parameters
        $finalState = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $parameters
        $finalState.Name | Should -Be $initialState.Name
        $finalState.Version | Should -Be $initialState.Version
        $finalState.Exist | Should -Be $initialState.Exist
    }

    It 'Sets desired extension in Insiders edition' -Skip:(!$IsWindows) {
        $desiredState = @{
            Name     = 'ms-azure-devops.azure-pipelines'
            Insiders = $true
        }

        Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name VSCodeExtension -ModuleName Microsoft.VSCode.Dsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be $desiredState.Name
        $finalState.Exist | Should -BeTrue
    }
}

AfterAll {
    # Uninstall VSCode?
}
