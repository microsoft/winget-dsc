# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.DotNet.Dsc

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.DotNet.Dsc PowerShell module.
#>

BeforeAll {
    Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    Import-Module Microsoft.DotNet.Dsc
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "DotNetToolPackage"
        $availableDSCResources = (Get-DscResource -Module Microsoft.DotNet.Dsc).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'DSC operation capabilities' {
    It 'Sets desired package' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'gitversion.tool'
        }
        
        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $finalState.Exist | Should -BeTrue
        $finalState.Version | Should -Not -BeNullOrEmpty
    }

    It 'Sets desired package with prerelease' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId  = 'dotnet-ef'
            PreRelease = $true
        }
        
        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $finalState.PackageId | Should -Be $parameters.PackageId
        $finalState.PreRelease | Should -BeTrue
    }

    It 'Sets desired package with version' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet-reportgenerator-globaltool'
            Version   = '5.3.9'
        }
        
        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $finalState.PackageId | Should -Be $parameters.PackageId
        $finalState.Version | Should -Be $parameters.Version
    }

    It 'Updates desired package with latest version' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet-reportgenerator-globaltool'
            Version   = '5.3.10'
        }
        
        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $finalState.PackageId | Should -Be $parameters.PackageId
        $finalState.Version | Should -Be $parameters.Version
    }

    It 'Sets desired package with prerelease version' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'PowerShell'
            Version   = '7.2.0-preview.5'
        }
        
        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters
     
        $finalState = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $finalState.PackageId | Should -Be $parameters.PackageId
        $finalState.Version | Should -Be $parameters.Version
        $finalState.PreRelease | Should -BeTrue
    }

    It 'Exports resources' -Skip:(!$IsWindows) {
        $obj = [DotNetToolPackage]::Export()
        
        $obj.PackageId.Contains('dotnet-ef') | Should -Be $true
        $obj.PackageId.Contains('dotnet-reportgenerator-globaltool') | Should -Be $true
    }

    It 'Throws error when resource is not a tool' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'Azure-Core' # not a tool
        }
        
        { Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters } | Should -Throw -ExpectedMessage "Executing dotnet.exe with {tool install Azure-Core --global --ignore-failed-sources} failed."
    }

    It 'Installs in tool path location with version' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet-dump'
            ToolPath  = 'C:\tools'
            Version   = '8.0.532401'
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters

        $state = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $state.Exist | Should -BeTrue
        $state.ToolPath | Should -Be $parameters.ToolPath
        $state::InstalledPackages[$parameters.PackageId].ToolPath | Should -Be $parameters.ToolPath # It should reflect updated export()
    }

    # TODO: Work on update scenario
    It 'Update in tool path location' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet-dump'
            ToolPath  = 'C:\tools'
            Version   = '8.0.547301'
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters

        $state = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $state.Exist | Should -BeTrue
        $state.ToolPath | Should -Be $parameters.ToolPath
        $state::InstalledPackages[$parameters.PackageId].ToolPath | Should -Be $parameters.ToolPath # It should reflect updated export()
    }

    It 'Uninstall a tool' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'gitversion.tool'
            Exist     = $false
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters

        $state = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $state.Exist | Should -BeFalse
    }

    It 'Uninstall a tool from tool path location' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'dotnet-dump'
            ToolPath  = 'C:\tools'
            Exist     = $false
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters

        $state = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $state.Exist | Should -BeFalse
    }
}
