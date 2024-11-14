# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.DotNet.Dsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.DotNet.Dsc PowerShell module.
#>

BeforeAll {
    Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    Import-Module Microsoft.DotNet.Dsc

    $script:toolsDir = Join-Path $env:USERPROFILE 'tools'

    if (-not (Test-Path $toolsDir)) {
        $null = New-Item -ItemType Directory -Path $toolsDir -Force -ErrorAction SilentlyContinue
    }
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'DotNetToolPackage'
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

        $obj.PackageId.Contains('gitversion.tool') | Should -Be $true
        $obj.PackageId.Contains('dotnet-reportgenerator-globaltool') | Should -Be $true
    }

    It 'Throws error when resource is not a tool' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'Azure-Core' # not a tool
        }

        { Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters } | Should -Throw -ExpectedMessage 'Executing dotnet.exe with {tool install Azure-Core --global --ignore-failed-sources} failed.'
    }

    It 'Installs in tool path location with version' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId         = 'dotnet-dump'
            ToolPathDirectory = $toolsDir
            Version           = '8.0.532401'
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters

        $state = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $state.Exist | Should -BeTrue
        $state.ToolPathDirectory | Should -Be $parameters.ToolPathDirectory
        $state::InstalledPackages[$parameters.PackageId].ToolPathDirectory | Should -Be $parameters.ToolPathDirectory # It should reflect updated export()
    }

    # TODO: Work on update scenario
    It 'Update in tool path location' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId         = 'dotnet-dump'
            ToolPathDirectory = $toolsDir
            Version           = '8.0.547301'
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters

        $state = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $state.Exist | Should -BeTrue
        $state.ToolPathDirectory | Should -Be $parameters.ToolPathDirectory
        $state::InstalledPackages[$parameters.PackageId].ToolPathDirectory | Should -Be $parameters.ToolPathDirectory # It should reflect updated export()
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
            PackageId         = 'dotnet-dump'
            ToolPathDirectory = $toolsDir
            Exist             = $false
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters

        $state = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $state.Exist | Should -BeFalse
    }

    It 'Downgrades a tool' -Skip:(!$IsWindows) {
        $parameters = @{
            PackageId = 'gitversion.tool' # should install latest version
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters

        $parameters = @{
            PackageId = 'gitversion.tool'
            Version   = '6.0.2'
        }

        Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Set -Property $parameters
        $state = Invoke-DscResource -Name DotNetToolPackage -ModuleName Microsoft.DotNet.Dsc -Method Get -Property $parameters
        $state.Version | Should -Be $parameters.Version
    }
}

Describe 'DSC helper functions' {
    Context 'Semantic Versioning' {
        It 'Parses valid semantic version' {
            $version = '1.2.3'
            $result = Get-SemVer -version $version
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 2
            $result.Build | Should -Be 3
        }

        It 'Parses semantic version with alpha' {
            $version = '1.2.3-alpha'
            $result = Get-SemVer -version $version
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 2
            $result.Build | Should -Be 3
            $result.Revision | Should -Be 0 # Because pre-release is not a number according the handling
        }

        It 'Parses semantic version with alpha tag and version' {
            $version = '1.2.3-alpha.123'
            $result = Get-SemVer -version $version
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 2
            $result.Build | Should -Be 3
            $result.Revision | Should -Be '123'
        }

        It 'Parses semantic version with beta tag and version' {
            $version = '1.2.3-beta.11'
            $result = Get-SemVer -version $version
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 2
            $result.Build | Should -Be 3
            $result.Revision | Should -Be '11'
        }

        It 'Parses semantic version with rc and version' {
            $version = '1.2.3-rc.1'
            $result = Get-SemVer -version $version
            $result.Major | Should -Be 1
            $result.Minor | Should -Be 2
            $result.Build | Should -Be 3
            $result.Revision | Should -Be '1'
        }
    }
}

AfterAll {
    Remove-Item -Path $toolsDir -Recurse -Force -ErrorAction SilentlyContinue
}
