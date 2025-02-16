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



Describe 'Get-RegistryStatus' -Tag 'Private' {
    Context 'When the registry key exists' {
        BeforeAll {
            Mock -CommandName Get-ItemPropertyValue -MockWith {
                return 1
            }
        }

        BeforeDiscovery {
            $testCases = @(
                @{
                    Path          = 'HKLM:\SOFTWARE\Microsoft\MdmCommon\SettingValues'
                    Name          = 'LocationSyncEnabled'
                    Status        = @{
                        'Enabled'  = '1'
                        'Disabled' = '0'
                        'Default'  = 'Unknown'
                    }
                    ExpectedValue = '1'
                    ExpectedKey   = 'Enabled'
                }
            )
        }

        It 'Should return the registry value ''<ExpectedKey>'' on ''<Path>''' -ForEach $testCases {
            InModuleScope -Parameters $_ -ScriptBlock {
                $result = Get-RegistryStatus -Path $Path -Name $Name -Status $Status
                $result | Should -Be $ExpectedKey
            }

            Should -Invoke -CommandName Get-ItemPropertyValue -Exactly -Times 1
        }
    }

    Context 'When the registry key does not exist' {
        BeforeAll {
            Mock -CommandName Get-ItemPropertyValue -MockWith {
                return $null
            }
        }

        It 'Should return empty result' {
            InModuleScope -ScriptBlock {
                $result = Get-RegistryStatus -Path 'HKLM:\1\2\3' -Name 'Empty' -Status @{}
                $result | Should -BeNullOrEmpty
            }

            Should -Invoke -CommandName Get-ItemPropertyValue -Exactly -Times 1
        }
    }
}
