[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:dscModuleName = 'Microsoft.Windows.Settings'

    Import-Module -Name $script:dscModuleName

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:dscModuleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'WindowsReason' -Tag 'WindowsReason' {
    Context 'When instantiating the class' {
        It 'Should not throw an error' {
            $script:mockWindowsReasonInstance = InModuleScope -ScriptBlock {
                [WindowsReason]::new()
            }
        }

        It 'Should be of the correct type' {
            $mockWindowsReasonInstance | Should -Not -BeNullOrEmpty
            $mockWindowsReasonInstance.GetType().Name | Should -Be 'WindowsReason'
        }
    }

    Context 'When setting an reading values' {
        It 'Should be able to set value in instance' {
            $script:mockWindowsReasonInstance = InModuleScope -ScriptBlock {
                $WindowsReasonInstance = [WindowsReason]::new()

                $WindowsReasonInstance.Code = 'WindowsReason:WindowsReason:Ensure'
                $WindowsReasonInstance.Phrase = 'The property Ensure should be "Present", but was "Absent"'

                return $WindowsReasonInstance
            }
        }

        It 'Should be able to read the values from instance' {
            $mockWindowsReasonInstance.Code | Should -Be 'WindowsReason:WindowsReason:Ensure'
            $mockWindowsReasonInstance.Phrase | Should -Be 'The property Ensure should be "Present", but was "Absent"'
        }
    }
}
