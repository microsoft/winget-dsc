using module PythonPip3Dsc

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the PythonPip3Dsc PowerShell module.
#>

BeforeAll {
    Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
    Import-Module PythonPip3Dsc

    if ($env:TF_BUILD) {
        Invoke-WebRequest https://raw.githubusercontent.com/KernFerm/Py3.12.1-installer-PS1/refs/heads/main/Py3.12.1-installer.ps1 -UseBasicParsing -OutFile Py3.12.1-installer.ps1.ps1
        .\Py3.12.1-installer.ps1
    }
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = "Pip3Package"
        $availableDSCResources = (Get-DscResource -Module PythonPip3Dsc).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'Pip3Package' {
    It 'Sets desired package' -Skip:(!$IsWindows) {
        $desiredState = @{
            Package = 'django'
        }
        
        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState
     
        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be $desiredState.Name
        $finalState.Exist | Should -BeTrue
    }

    It 'Sets desired package with version' -Skip:(!$IsWindows) {
        $desiredState = @{
            Package = 'flask'
            Version  = '3.0.3'
        }
        
        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState
     
        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be $desiredState.Name
        $finalState.Exist | Should -BeTrue
        $finalState.Version | Should -Be $desiredState.Version  
    }

    It 'Handles non-existent package gracefully' -Skip:(!$IsWindows) {
        $desiredState = @{
            Package = 'nonexistentpackage'
        }

        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Test -Property $desiredState
        $finalState.InDesiredState | Should -Be $false
    }

    It 'Removes package if not desired' -Skip:(!$IsWindows) {
        $desiredState = @{
            Package = 'numpy'
        }

        # Ensure the package is installed first
        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        # Now remove the package
        $desiredState = @{
            Package = 'numpy'
            Exist    = $false
        }

        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Get -Property $desiredState
        $finalState.Exist | Should -BeFalse
    }
}
