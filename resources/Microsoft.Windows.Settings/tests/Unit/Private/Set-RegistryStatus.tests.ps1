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


Describe 'Set-RegistryStatus' -Tag 'Private' {
    Context 'Set registry key when it already exist' {
        BeforeAll {
            Mock -CommandName Set-ItemProperty -MockWith {
                return 1
            }
        }

        BeforeDiscovery {
            $testCases = @(
                @{
                    Path        = 'HKLM:\SOFTWARE\Microsoft\MdmCommon\SettingValues'
                    Name        = 'LocationSyncEnabled'
                    Value       = '1'
                    ExpectedKey = @{
                        'LocationSyncEnabled' = '1'
                    }
                }
            )
        }

        It 'Should set the registry key' -ForEach $testCases {
            InModuleScope -Parameters $_ -ScriptBlock {
                $result = Set-RegistryStatus -Path $Path -Name $Name -Value $Value
                $result | Should -Be $ExpectedKey.LocationSyncEnabled
            }

            Should -Invoke -CommandName Set-ItemProperty -Exactly -Times 1
        }
    }

    Context 'Set registry key when it does not exist' {
        BeforeAll {
            Mock -CommandName New-Item
            Mock -CommandName Set-ItemProperty -MockWith {
                return 0
            }
        }

        BeforeDiscovery {
            $testCases = @(
                @{
                    Path        = 'HKCU:\1\2\3'
                    Name        = 'MyValue'
                    Value       = '0'
                    ExpectedKey = $null
                }
            )
        }

        It 'Should set the registry key' -ForEach $testCases {
            InModuleScope -Parameters $_ -ScriptBlock {
                $result = Set-RegistryStatus -Path $Path -Name $Name -Value $Value
                $result | Should -Be $ExpectedKey
            }

            Should -Invoke -CommandName New-Item -Exactly -Times 1
            # Should -Invoke -CommandName Set-ItemProperty -Exactly -Times 1
        }
    }
}
