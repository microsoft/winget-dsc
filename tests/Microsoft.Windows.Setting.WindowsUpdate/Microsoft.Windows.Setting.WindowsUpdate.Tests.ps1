# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Setting.WindowsUpdate

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.WindowsUpdate PowerShell module.
#>

BeforeAll {
    Import-Module Microsoft.Windows.Setting.WindowsUpdate
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "WindowsUpdate"
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.WindowsUpdate).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}