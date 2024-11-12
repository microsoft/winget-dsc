using module PythonPip3Dsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the PythonPip3Dsc PowerShell module.
#>

BeforeAll {
    # Before import module make sure Python is installed
    if ($env:TF_BUILD) {
        $outFile = Join-Path $env:TEMP 'python.exe'
        Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.14.0/python-3.14.0a1-amd64.exe' -UseBasicParsing -OutFile $outFile
        & $outFile /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    }

    Import-Module PythonPip3Dsc -Force -ErrorAction SilentlyContinue
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'Pip3Package'
        $availableDSCResources = (Get-DscResource -Module PythonPip3Dsc).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'Pip3Package' {
    It 'Sets desired package' -Skip:(!$IsWindows) {
        $desiredState = @{
            PackageName = 'django'
        }

        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Get -Property $desiredState
        $finalState.PackageName | Should -Be $desiredState.PackageName
        $finalState.Exist | Should -BeTrue
    }

    It 'Sets desired package with version' -Skip:(!$IsWindows) {
        $desiredState = @{
            PackageName = 'flask'
            Version     = '3.0.3'
        }

        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Get -Property $desiredState
        $finalState.PackageName | Should -Be $desiredState.PackageName
        $finalState.Exist | Should -BeTrue
        $finalState.Version | Should -Be $desiredState.Version
    }

    It 'Updates with specific version' -Skip:(!$IsWindows) {
        $desiredState = @{
            PackageName = 'requests'
            Version     = '2.32.2'
        }

        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        # Now update the package to a newer version
        $desiredState.Version = '2.32.3'
        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Get -Property $desiredState
        $finalState.PackageName | Should -Be $desiredState.PackageName
        $finalState.Exist | Should -BeTrue
        $finalState.Version | Should -Be $desiredState.Version
    }

    It 'Handles non-existent package gracefully' -Skip:(!$IsWindows) {
        $desiredState = @{
            PackageName = 'nonexistentpackage'
        }

        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Test -Property $desiredState
        $finalState.InDesiredState | Should -Be $false
    }

    It 'Removes package if not desired' -Skip:(!$IsWindows) {
        $desiredState = @{
            PackageName = 'numpy'
        }

        # Ensure the package is installed first
        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        # Now remove the package
        $desiredState = @{
            PackageName = 'numpy'
            Exist       = $false
        }

        Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name Pip3Package -ModuleName PythonPip3Dsc -Method Get -Property $desiredState
        $finalState.Exist | Should -BeFalse
    }

    It 'Performs whatif operation successfully' -Skip:(!$IsWindows) {
        $whatIfState = @{
            PackageName = 'itsdangerous'
            Version     = '2.2.0'
            Exist       = $false
        }

        $pipPackage = [Pip3Package]$whatIfState

        # Uninstall to make sure it is not present
        $pipPackage.Set()

        $whatIf.Exist = $true

        # Call whatif to see if it "will" install
        $whatIf = $pipPackage.WhatIf() | ConvertFrom-Json
        
        $whatIf.PackageName | Should -Be 'itsdangerous'
        $whatIf._metaData.whatIf | Should -Contain "Would install itsdangerous-$($whatIfState.Version)"
    }

    It 'Does not return whatif result if package is invalid' -Skip:(!$IsWindows) {
        $whatIfState = @{
            PackageName = 'its-dangerous'
        }

        $pipPackage = [Pip3Package]$whatIfState
        $whatIf = $pipPackage.WhatIf() | ConvertFrom-Json
        

        $whatIf.PackageName | Should -Be 'its-dangerous'
        $whatIf._metaData.whatIf | Should -Contain "ERROR: No matching distribution found for $($whatIfState.PackageName)"
    }
}
