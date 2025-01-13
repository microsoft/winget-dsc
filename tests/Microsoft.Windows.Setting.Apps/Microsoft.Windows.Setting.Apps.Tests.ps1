# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.Apps

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.Apps PowerShell module.
#>

BeforeAll {
    if ((Get-Module -ListAvailable -Name PSDesiredStateConfiguration -ErrorAction SilentlyContinue).Version -eq '2.0.7') {
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    }

    Import-Module Microsoft.Windows.Setting.Apps -Force
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'AdvancedAppSettings', 'AppExecutionAliases', 'OfflineMap'
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Apps).Name
        $availableDSCResources.Count | Should -Be 3
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'AdvancedAppSettings' {
    It 'Set app source preference' {
        $desiredState = @{
            AppSourcePreference   = 'StoreOnly'
            ShareDeviceExperience = 'Device'
            ArchiveApp            = $false
        }
        Invoke-DscResource -Name AdvancedAppSettings -ModuleName Microsoft.Windows.Setting.Apps -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name AdvancedAppSettings -ModuleName Microsoft.Windows.Setting.Apps -Method Get -Property @{}
        $finalState.AppSourcePreference | Should -Be 'StoreOnly'
        $finalState.ShareDeviceExperience | Should -Be 'Device'
        $finalState.ArchiveApp | Should -Be $false
    }
}

Describe 'OfflineMap' {
    Context 'Package availability' {
        $testCases = Get-GeoLocationCoordinate -ReturnAddress

        It '[<_>] Get offline map package availability' -TestCases $testCases {
            param (
                [string]$Address
            )

            $offlineMap = Get-OfflineMapPackage -Address $_
            $offlineMap.Packages | Should -Not -BeNullOrEmpty
        }
    }
}
