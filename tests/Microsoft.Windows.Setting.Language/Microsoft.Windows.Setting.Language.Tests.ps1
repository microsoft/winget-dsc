using module Microsoft.Windows.Setting.Language

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.Windows.Setting.Language PowerShell module.
#>

BeforeAll {
    Import-Module Microsoft.Windows.Setting.Language -Force -ErrorAction SilentlyContinue
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = @('Language', 'DisplayLanguage', 'Region')
        $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Setting.Language).Name
        $availableDSCResources.count | Should -Be 3
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'Language' {
    It 'Install a preferred language' -Skip:(!$IsWindows) {
        $desiredState = @{
            LocaleName = 'en-GB'
        }

        Invoke-DscResource -Name Language -ModuleName Microsoft.Windows.Setting.Language -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Language -ModuleName Microsoft.Windows.Setting.Language -Method Get -Property $desiredState
        $finalState.Exist | Should -BeTrue
    }

    It 'Uninstall a preferred language' -Skip:(!$IsWindows) {
        $desiredState = @{
            LocaleName = 'en-GB'
        }

        Invoke-DscResource -Name Language -ModuleName Microsoft.Windows.Setting.Language -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Language -ModuleName Microsoft.Windows.Setting.Language -Method Get -Property $desiredState
        $finalState.Exist | Should -BeFalse
    }

    It 'Export all languages' -Skip:(!$IsWindows) {

        $class = [Language]::new()

        $currentLanguages = $class::Export()
        $currentLanguages | Should -Not -BeNullOrEmpty
        $currentLanguages.Count | Should -BeGreaterThan 0
    }
}

Describe 'DisplayLanguage' {
    It 'Set a preferred language' -Skip:(!$IsWindows) {
        $desiredState = @{
            LocaleName = 'en-US'
        }

        Invoke-DscResource -Name DisplayLanguage -ModuleName Microsoft.Windows.Setting.Language -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name DisplayLanguage -ModuleName Microsoft.Windows.Setting.Language -Method Get -Property $desiredState
        $finalState.Exist | Should -BeTrue
    }
}

Describe 'Region' {
    It 'Set a preferred region' -Skip:(!$IsWindows) {
        $desiredState = @{
            GeoId = '244'
        }

        Invoke-DscResource -Name Region -ModuleName Microsoft.Windows.Setting.Language -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Region -ModuleName Microsoft.Windows.Setting.Language -Method Get -Property $desiredState
        $finalState.Exist | Should -BeTrue
    }
}
