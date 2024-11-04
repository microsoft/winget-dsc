using module Microsoft.Windows.Setting.Language

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Settings.Language PowerShell module.
#>

BeforeAll {
    Import-Module Microsoft.Windows.Settings.Language -Force -ErrorAction SilentlyContinue
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "Language"
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Settings.Language).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}
