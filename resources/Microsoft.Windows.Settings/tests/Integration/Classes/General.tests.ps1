<#
    .SYNOPSIS
        Integration test for FindMyDevice DSC class resource.
#>

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'PSDesiredStateConfiguration'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'PSDesiredStateConfiguration' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'PSDesiredStateConfiguration' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'PSDesiredStateConfiguration module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:dscModuleName = 'Microsoft.Windows.Settings'
    $script:dscResourceName = 'General'

    Import-Module -Name $script:dscModuleName -Force

    $script:instance = & (Import-Module $script:dscModuleName -PassThru) ([scriptblock]::Create("'$script:dscResourceName' -as 'type'"))
    $script:currentState = $script:instance::new().Get()

    $PSDefaultParameterValues['Invoke-DscResource:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Invoke-DscResource:Name'] = $script:instance.Name 
}

AfterAll {
    $PSDefaultParameterValues.Remove('Invoke-DscResource:ModuleName')
    $PSDefaultParameterValues.Remove('Invoke-DscResource:Name')

    Write-Verbose -Message "Restoring the original state of the $($script:dscResourceName) setting."
    $script:currentState.Set()
}

Describe "General\Generic" {
    Context "List available DSC resources" {
        It 'Shows DSC resources' {
            $expectedDscResources = @('General')

            $availableDscResources = (Get-DscResource -Module $script:dscModuleName -Name $expectedDscResources).Name
            $availableDscResources.count | Should -Be 1
            $availableDscResources | Where-Object { $expectedDscResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
        }
    }
}

Describe "Generic\Integration" {
    Context "Generic\Set" {
        It 'Sets <property> to <value>' -TestCases @(
            @{ Property = 'EnablePersonalizedAds'; Value = 'Disabled' },
            @{ Property = 'EnableLocalContentByLanguageList'; Value = 'Enabled' },
            @{ Property = 'EnableAppLaunchTracking'; Value = 'Enabled' },
            @{ Property = 'ShowContentSuggestion'; Value = 'Enabled' },
            @{ Property = 'EnableAccountNotifications'; Value = 'Disabled' }
        ) {
            param ($Property, $Value)
            $desiredState = @{ $Property = $Value }

            Invoke-DscResource -Method Set -Property $desiredState

            $finalState = Invoke-DscResource -Method Get -Property $desiredState
            $finalState.$Property | Should -Be $Value
        }
    }
}