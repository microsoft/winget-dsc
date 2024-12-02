using module NpmDsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the NpmDsc PowerShell module.
#>

BeforeAll {
    # Before import module make sure NpmDsc is installed
    Import-Module NpmDsc -Force -ErrorAction SilentlyContinue

    if ($env:TF_BUILD) {
        $versionsUri = 'https://nodejs.org/dist/index.json'
        Write-Verbose -Message "Checking NodeJS versions from $versionsUri" -Verbose
        $versions = Invoke-RestMethod -Uri $versionsUri -UseBasicParsing

        $latestVersion = $versions[0].version
        $fileName = "node-$latestVersion-x64.msi"
        $64uri = "https://nodejs.org/dist/$latestVersion/$fileName"
        $outFile = Join-Path -Path $env:TEMP -ChildPath $fileName

        Write-Verbose -Message "Downloading $64uri to $outFile" -Verbose
        Invoke-RestMethod -Uri $64uri -OutFile $outFile -UseBasicParsing

        # Install NodeJS
        $DataStamp = Get-Date -Format yyyyMMddTHHmmss
        $logFile = '{0}-{1}.log' -f "node-$latestVersion-x64", $DataStamp
        $arguments = @(
            '/i'
            ('"{0}"' -f $outFile)
            '/quiet'
            'ADDLOCAL=ALL'
            '/L*v'
            $logFile
        )
        Start-Process 'msiexec.exe' -ArgumentList $arguments -Wait -NoNewWindow

        Write-Verbose -Message ("Finished installing NodeJS: '{0}'" -f (node --version)) -Verbose

        # Clean up the npm cache log directory
        $logFiles = Get-ChildItem (GetNpmPath) -Filter '*.log' -Recurse -ErrorAction SilentlyContinue
        $logFiles | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # Reduce the noise for npm
    $env:NODE_OPTIONS = '--disable-warning=ExperimentalWarning'
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'NpmPackage', 'NpmInstall'
        $availableDSCResources = (Get-DscResource -Module NpmDsc).Name
        $availableDSCResources.count | Should -Be 2
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'NpmPackage' {
    It 'Install react package globally' -Skip:(!$IsWindows) {
        $desiredState = @{
            Name   = 'react'
            Global = $true
        }

        Invoke-DscResource -Name NpmPackage -ModuleName NpmDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name NpmPackage -ModuleName NpmDsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be $desiredState.Name
        $finalState.Ensure | Should -Be 'Present'
    }

    It 'Uninstall react package globally' -Skip:(!$IsWindows) {
        $desiredState = @{
            Name   = 'react'
            Global = $true
            Ensure = 'Absent'
        }

        Invoke-DscResource -Name NpmPackage -ModuleName NpmDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name NpmPackage -ModuleName NpmDsc -Method Test -Property $desiredState
        $finalState.InDesiredState | Should -Be $true
    }

    It 'Performs whatif operation successfully' -Skip:(!$IsWindows) {
        $whatIfState = @{
            Name   = 'react'
            Global = $true
            Ensure = 'Absent'
        }

        $npmPackage = [NpmPackage]$whatIfState

        # Uninstall to make sure it is not present
        $npmPackage.Set()

        $npmPackage.Ensure = 'Present'

        # Call whatif to see if it "will" install
        $whatIf = $npmPackage.WhatIf() | ConvertFrom-Json

        # Don't want to rely on version in parameters so we call npm view to get the remote version
        $latestVersion = Invoke-Npm -Command "view $($whatIfState.Name) version"

        $whatIf.Name | Should -Be 'react'
        $whatIf._metaData.whatIf | Should -Contain "add react $latestVersion"
    }

    It 'Does not return whatif result if package is invalid' -Skip:(!$IsWindows) {
        $whatIfState = @{
            Name   = 'invalidPackageName'
            Global = $true
        }

        $npmPackage = [NpmPackage]$whatIfState
        $whatIf = $npmPackage.WhatIf() | ConvertFrom-Json

        Write-Verbose -Message ($whatIf | ConvertTo-Json -Depth 5 | Out-String) -Verbose

        $whatIf.Name | Should -Be 'invalidPackageName'
        $whatIf._metaData.whatIf | Should -Contain "error 404 Not Found - GET https://registry.npmjs.org/$($whatIfState.Name) - Not found"
    }

    It 'Returns empty result if ensure is absent' -Skip:(!$IsWindows) {
        $whatIfState = @{
            Name   = 'invalidPackageName'
            Ensure = 'Absent'
        }

        $npmPackage = [NpmPackage]$whatIfState
        $whatIf = $npmPackage.WhatIf() | ConvertFrom-Json

        $whatIf | Should -BeNullOrEmpty -Because "Uninstall does not have '--dry-run'"
    }

    It 'Should be able to export npm packages' -Skip:(!$IsWindows) {
        $whatIfState = @{
            Name   = 'react'
            Global = $true
        }

        $npmPackage = [NpmPackage]$whatIfState
        # Install at least one package
        $npmPackage.Set()

        $exportedState = $npmPackage::Export()

        $exportedState.Count | Should -BeGreaterOrEqual 1
    }
}
