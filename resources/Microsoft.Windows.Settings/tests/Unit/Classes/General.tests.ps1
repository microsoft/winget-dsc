﻿<#
    .SYNOPSIS
        Unit test for FindMyDevice DSC class resource.
#>

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

Describe 'General' {
    Context 'When class is instantiated' {
        It 'Should not throw an exception' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                { [General]::new() } | Should -Not -Throw
            }
        }

        It 'Should have a default or empty constructor' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $instance = [General]::new()
                $instance | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should be the correct type' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $instance = [General]::new()
                $instance.GetType().Name | Should -Be 'General'
            }
        }
    }
}

Describe 'General\Get()' -Tag 'Get' {
    Context 'When getting the status of general settings' {
        BeforeAll {
            InModuleScope -Scriptblock {
                Set-StrictMode -Version 1.0

                $script:mockInstance = [General]@{
                    IsSingleInstance = 'Yes'
                }

                <#
                        This mocks the method GetCurrentState().

                        Method Get() will call the base method Get() which will
                        call back to the derived class method GetCurrentState()
                        to get the result to return from the derived method Get().
                    #>
                $script:mockInstance |
                    Add-Member -Force -MemberType 'ScriptMethod' -Name 'GetCurrentState' -Value {
                        return @{
                            IsSingleInstance      = 'Yes'
                            EnablePersonalizedAds = [SettingStatus]::Disabled
                        }
                    } -PassThru |
                        Add-Member -Force -MemberType 'ScriptMethod' -Name 'AssertProperties' -Value {
                            return
                        }
            }
        }

        It 'Should return the correct values' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $currentState = $script:mockInstance.Get()

                $currentState.IsSingleInstance | Should -Be 'Yes'
                $currentState.EnablePersonalizedAds | Should -Be 'Disabled'

                $currentState.Reasons | Should -BeNullOrEmpty
            }
        }
    }
}

Describe 'General\Set()' -Tag 'Set' {
    BeforeAll {
        InModuleScope -Scriptblock {
            Set-StrictMode -Version 1.0

            $script:mockInstance = [General]@{
                IsSingleInstance = 'Yes'
            } |
                # Mock method Modify which is called by the case method Set().
                Add-Member -Force -MemberType 'ScriptMethod' -Name 'Modify' -Value {
                    $script:methodModifyCallCount += 1
                } -PassThru
        }
    }

    BeforeEach {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $script:methodModifyCallCount = 0
        }
    }

    Context 'When the system is in the desired state' {
        BeforeAll {
            InModuleScope -Scriptblock {
                Set-StrictMode -Version 1.0

                $script:mockInstance |
                    # Mock method Compare() which is called by the base method Set()
                    Add-Member -Force -MemberType 'ScriptMethod' -Name 'Compare' -Value {
                        return $null
                    } -PassThru |
                        Add-Member -Force -MemberType 'ScriptMethod' -Name 'AssertProperties' -Value {
                            return
                        }
            }
        }

        It 'Should not call method Modify()' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $script:mockInstance.Set()

                $script:methodModifyCallCount | Should -Be 0
            }
        }
    }

    Context 'When the system is not in the desired state' {
        BeforeAll {
            InModuleScope -Scriptblock {
                Set-StrictMode -Version 1.0

                $script:mockInstance |
                    # Mock method Compare() which is called by the base method Set()
                    Add-Member -Force -MemberType 'ScriptMethod' -Name 'Compare' -Value {
                        return @(
                            @{
                                Property      = 'EnablePersonalizedAds'
                                ExpectedValue = 'Disabled'
                                ActualValue   = 'Enabled'
                            }
                        )
                    } -PassThru |
                        Add-Member -Force -MemberType 'ScriptMethod' -Name 'AssertProperties' -Value {
                            return
                        }
            }
        }

        It 'Should call method Modify()' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $script:mockInstance.Set()

                $script:methodModifyCallCount | Should -Be 1
            }
        }
    }
}

Describe 'General\Test()' -Tag 'Test' {
    Context 'When the system is in the desired state' {
        BeforeAll {
            InModuleScope -Scriptblock {
                Set-StrictMode -Version 1.0

                $script:mockInstance |
                    # Mock method Compare() which is called by the base method Test()
                    Add-Member -Force -MemberType 'ScriptMethod' -Name 'Compare' -Value {
                        return $null
                    } -PassThru |
                        Add-Member -Force -MemberType 'ScriptMethod' -Name 'AssertProperties' -Value {
                            return
                        }
            }
        }

        It 'Should return $true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $script:mockInstance.Test() | Should -BeTrue
            }
        }
    }

    Context 'When the system is not in the desired state' {
        BeforeAll {
            InModuleScope -Scriptblock {
                Set-StrictMode -Version 1.0

                $script:mockInstance |
                    # Mock method Compare() which is called by the base method Test()
                    Add-Member -Force -MemberType 'ScriptMethod' -Name 'Compare' -Value {
                        return @(
                            @{
                                Property      = 'EnablePersonalizedAds'
                                ExpectedValue = $false
                                ActualValue   = $true
                            })
                    } -PassThru |
                        Add-Member -Force -MemberType 'ScriptMethod' -Name 'AssertProperties' -Value {
                            return
                        }
            }
        }

        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $script:mockInstance.Test() | Should -BeFalse
            }
        }
    }
}

Describe 'General\GetCurrentState()' -Tag 'HiddenMember' {
    Context 'When object is missing in the current state' {
        BeforeAll {
            InModuleScope -Scriptblock {
                Set-StrictMode -Version 1.0

                $script:mockInstance = [General] @{
                    EnablePersonalizedAds = 'Disabled'
                }
            }
        }

    }

    It 'Should return the correct values' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $currentState = $script:mockInstance.GetCurrentState(
                @{
                    IsSingleInstance = 'Yes'
                }
            )

            $currentState.IsSingleInstance | Should -BeNullOrEmpty
            $currentState.EnablePersonalizedAds | Should -Be 'Disabled'
        }
    }
}


Describe 'General\Set()' -Tag 'HiddenMember' {
    BeforeAll {
        Mock -CommandName Set-RegistryStatus
        Mock -CommandName New-ItemProperty -MockWith { return $true }
    }

    Context 'When setting the registry key for "EnablePersonalizedAds"' {
        BeforeAll {
            InModuleScope -Scriptblock {
                Set-StrictMode -Version 1.0

                $script:mockInstance = [General]@{
                    EnablePersonalizedAds = 'Enabled'
                }
            }
        }

        It 'Should call the correct mock' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $script:mockInstance.Set()
            }

            Should -Invoke -CommandName Set-RegistryStatus -Exactly -Times 1 -Scope It
        }
    }
}
