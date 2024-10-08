# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.NET.SDK.ToolInstaller

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.NET.SDK.ToolInstaller PowerShell module.
#>

BeforeAll {
    Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    Import-Module Microsoft.NET.SDK.ToolInstaller
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "NETSDKToolInstaller"
        $availableDSCResources = (Get-DscResource -Module Microsoft.NET.SDK.ToolInstaller).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'DSC operation capabilities' {
    It 'Test for empty package.' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet'
        }
        
        $testResult = Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Test -Property $parameters -Verbose -Debug
        $testResult.InDesiredState | Should -Be $false # because is empty
    }

    It 'Sets desired package' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'GitVersion.Tool'
        }
        
        Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Get -Property $parameters
        $finalState.PackageId | Should -Be $parameters.PackageId
        $finalState.Exist | Should -BeTrue
     }

     It 'Sets desired package with prerelease' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet-ef'
            PreRelease = $true
        }
        
        Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Get -Property $parameters
        $finalState.PackageId | Should -Be $parameters.PackageId
        $finalState.PreRelease | Should -BeTrue
     }

     It 'Sets desired package with version' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet-reportgenerator-globaltool'
            Version = '5.3.10'
        }
        
        Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Get -Property $parameters
        $finalState.PackageId | Should -Be $parameters.PackageId
        $finalState.Version | Should -Be $parameters.Version
     }

     It 'Sets desired package with prerelease version' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'PowerShell'
            Version = '7.2.0-preview.5'
        }
        
        Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Get -Property $parameters
        $finalState.PackageId | Should -Be $parameters.PackageId
        $finalState.Version | Should -Be $parameters.Version
        $finalState.PreRelease | Should -BeTrue
     }

     It 'Exports resources' -Skip:(!$IsWindows) {
        $obj = [NETSDKToolInstaller]::Export()
        
        $obj.PackageId.Contains('cake.tool') | Should -Be $true
        $obj.PackageId.Contains('GitVersion.Tool') | Should -Be $true
     }

     It 'Throws error when resource is not a tool' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'Azure-Core' # not a tool
        }
        
        {Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Set -Property $parameters} | Should -Throw -ExpectedMessage "Executing dotnet.exe with {tool install Azure-Core --no-cache --global} failed."
     }

    It 'Installs in tool path location' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet-dump'
            ToolPath  = 'C:\tools'
        }

        Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Set -Property $parameters

        $state = Invoke-DscResource -Name NETSDKToolInstaller -ModuleName Microsoft.NET.SDK.ToolInstaller -Method Get -Property $parameters
        $state.Exist | Should -BeTrue
        $state.ToolPath | Should -Be $parameters.ToolPath
        $state::InstalledPackages[$parameters.PackageId].ToolPath | Should -Be $parameters.ToolPath # It should reflect updated export()
    }
}
