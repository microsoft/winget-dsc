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

Describe 'Get-RegistryKeyData' -Tag 'Private' {
    Context 'Get entry from key data' {
        BeforeAll {
            Mock -CommandName Import-PowerShellDataFile -MockWith {
                return @{
                    General = @{
                        PropertyName = 'General'
                        Name         = 'Key'
                        Path         = 'HKCU:\1\2\3'
                        Status       = @{
                            Enabled  = 1
                            Disabled = 0
                            Default  = 0
                        }
                    }
                }
            }
        }

        It 'Should return a result set' {
            InModuleScope -ScriptBlock {
                $result = Get-RegistryKeyData -Key General
                $result | Should -BeOfType 'System.Collections.Hashtable'
            }

            Should -Invoke -CommandName Import-PowerShellDataFile -Exactly -Times 1
        }
    }

    Context 'Get only path and name' {
        BeforeAll {
            Mock -CommandName Import-PowerShellDataFile -MockWith {
                return @{
                    General = @{
                        PropertyName = 'General'
                        Name         = 'Key'
                        Path         = 'HKCU:\1\2\3'
                        Status       = @{
                            Enabled  = 1
                            Disabled = 0
                            Default  = 0
                        }
                    }
                }
            }
        }

        It 'Should return key path and name' {
            InModuleScope -ScriptBlock {
                $result = Get-RegistryKeyData -Key General -OnlyKeyPath
                $result.Path | Should -Not -BeNullOrEmpty
                $result.Name | Should -Not -BeNullOrEmpty
            }
        }
    }
}
