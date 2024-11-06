# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module Microsoft.Windows.Assertion

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the Microsoft.WinGet.Developer PowerShell module.
#>

BeforeAll {
   if ($null -eq (Get-Module -ListAvailable -Name PSDesiredStateConfiguration)) {
      Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
   }
   Import-Module Microsoft.Windows.Assertion
}

Describe 'List available DSC resources' {
   It 'Shows DSC Resources' {
      $expectedDSCResources = 'OsEditionId', 'SystemArchitecture', 'ProcessorArchitecture', 'HyperVisor', 'OsInstallDate', 'OsVersion', 'CsManufacturer', 'CsModel', 'CsDomain', 'PowerShellVersion', 'PnPDevice'
      $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Assertion).Name
      $availableDSCResources.length | Should -Be 11
      $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
   }
}

InModuleScope -ModuleName Microsoft.Windows.Assertion {
   Describe 'SystemArchitecture' {
      BeforeAll {
         Mock Get-ComputerInfo { return @{OsArchitecture = 'TestValue' } }
      }

      $script:SystemArchitectureResource = [SystemArchitecture]::new()

      It 'Get Current Property' -Tag 'Get' {
         $SystemArchitectureResource.Get().Architecture | Should -Be 'TestValue'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should match' {
            $SystemArchitectureResource.Architecture = 'TestValue'
            $SystemArchitectureResource.Test() | Should -Be $true
         }
         It 'Should not match' {
            $SystemArchitectureResource.Architecture = 'Value'
            $SystemArchitectureResource.Test() | Should -Be $false
         }
      }
   }

   Describe 'OsEditionId' {
      BeforeAll {
         Mock Get-ComputerInfo { return @{WindowsEditionId = 'TestValue' } }
      }

      $script:OsEditionResource = [OsEditionId]::new()

      It 'Get Current Property' -Tag 'Get' {
         $OsEditionResource.Get().Edition | Should -Be 'TestValue'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should match' {
            $OsEditionResource.Edition = 'TestValue'
            $OsEditionResource.Test() | Should -Be $true
         }
         It 'Should not match' {
            $OsEditionResource.Edition = 'Value'
            $OsEditionResource.Test() | Should -Be $false
         }
      }
   }

   Describe 'ProcessorArchitecture' {
      BeforeAll {
         $script:CurrentArchitecture = $env:PROCESSOR_ARCHITECTURE
         $env:PROCESSOR_ARCHITECTURE = 'TestValue'
      }

      $script:ProcessorArchitectureResource = [ProcessorArchitecture]::new()

      It 'Get Current Property' -Tag 'Get' {
         $ProcessorArchitectureResource.Get().Architecture | Should -Be 'TestValue'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should match' {
            $ProcessorArchitectureResource.Architecture = 'TestValue'
            $ProcessorArchitectureResource.Test() | Should -Be $true
         }
         It 'Should not match' {
            $ProcessorArchitectureResource.Architecture = 'Value'
            $ProcessorArchitectureResource.Test() | Should -Be $false
         }
      }

      AfterAll {
         $env:PROCESSOR_ARCHITECTURE = $script:CurrentArchitecture
      }

   }

   Describe 'HyperVisor' {
      BeforeAll {
         Mock Get-ComputerInfo { return @{HyperVisorPresent = $true } }
      }

      $script:HyperVisorResource = [HyperVisor]::new()

      It 'Get Current Property' -Tag 'Get' {
         $HyperVisorResource.Get().Ensure | Should -Be 'Present'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should match' {
            $HyperVisorResource.Ensure = 'Present'
            $HyperVisorResource.Test() | Should -Be $true
         }
         It 'Should not match' {
            $HyperVisorResource.Ensure = 'Absent'
            $HyperVisorResource.Test() | Should -Be $false
         }
      }
   }

   Describe 'OsInstallDate' {
      BeforeAll {
         $script:MockOsInstallDate = 'Saturday, November 2, 2024 12:30:00 AM'
         Mock Get-ComputerInfo { return @{OsInstallDate = $script:MockOsInstallDate } }
      }

      $script:OsInstallDateResource = [OsInstallDate]::new()

      It 'Get Current Property' -Tag 'Get' {
         $initialState = $OsInstallDateResource.Get()
         [String]::IsNullOrEmpty($initialState.Before) | Should -Be $true
         [String]::IsNullOrEmpty($initialState.After) | Should -Be $true
         $initialState.InstallDate | Should -Be $([System.DateTimeOffset]::Parse($script:MockOsInstallDate))
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should match between dates' {
            $OsInstallDateResource.Before = 'Sunday, November 3, 2024 12:00:00 AM'
            $OsInstallDateResource.After = 'Friday, November 1, 2024 12:00:00 AM'
            $OsInstallDateResource.Test() | Should -Be $true
         }
         It 'Should fail if before constraint is violated' {
            $OsInstallDateResource.Before = 'Friday, November 1, 2024 12:00:00 AM'
            $OsInstallDateResource.Test() | Should -Be $false
         }
         It 'Should fail if after constraint is violated' {
            $OsInstallDateResource.After = 'Sunday, November 3, 2024 12:00:00 AM'
            $OsInstallDateResource.Test() | Should -Be $false
         }
         It 'Should take minutes and seconds into consideration' {
            $OsInstallDateResource.Before = 'Saturday, November 2, 2024 12:29:59 AM'
            $OsInstallDateResource.Test() | Should -Be $false
         }
         It 'Should throw if before is not a date' {
            $OsInstallDateResource.Before = 'This is not a date'
            { $OsInstallDateResource.Test() } | Should -Throw
         }
         It 'Should throw if after is not a date' {
            $OsInstallDateResource.Before = 'This is not a date'
            { $OsInstallDateResource.Test() } | Should -Throw
         }
      }
   }

   Describe 'OsVersion' {
      BeforeAll {
         Mock Get-ComputerInfo { return @{OsVersion = '1.2.0' } }
      }

      $script:OsVersionResource = [OsVersion]::new()

      It 'Get Current Property' -Tag 'Get' {
         $initialState = $OsVersionResource.Get()
         [String]::IsNullOrEmpty($initialState.MinVersion) | Should -Be $true
         $initialState.OsVersion | Should -Be '1.2.0'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should succeed' {
            $OsVersionResource.MinVersion = '1.0.0'
            $OsVersionResource.Test() | Should -Be $true
         }
         It 'Should fail' {
            $OsVersionResource.MinVersion = '1.2.1'
            $OsVersionResource.Test() | Should -Be $false
         }
         It 'Should throw if MinVersion is not a version' {
            $OsVersionResource.MinVersion = 'This is not a version'
            { $OsVersionResource.Test() } | Should -Throw
         }
      }
   }

   Describe 'CsManufacturer' {
      BeforeAll {
         Mock Get-ComputerInfo { return @{CsManufacturer = 'TestValue' } }
      }

      $script:CsManufacturerResource = [CsManufacturer]::new()

      It 'Get Current Property' -Tag 'Get' {
         $CsManufacturerResource.Get().Manufacturer | Should -Be 'TestValue'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should match' {
            $CsManufacturerResource.Manufacturer = 'TestValue'
            $CsManufacturerResource.Test() | Should -Be $true
         }
         It 'Should not match' {
            $CsManufacturerResource.Manufacturer = 'Value'
            $CsManufacturerResource.Test() | Should -Be $false
         }
      }
   }

   Describe 'CsModel' {
      BeforeAll {
         Mock Get-ComputerInfo { return @{CsModel = 'TestValue' } }
      }

      $script:CsModelResource = [CsModel]::new()

      It 'Get Current Property' -Tag 'Get' {
         $CsModelResource.Get().Model | Should -Be 'TestValue'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should match' {
            $CsModelResource.Model = 'TestValue'
            $CsModelResource.Test() | Should -Be $true
         }
         It 'Should not match' {
            $CsModelResource.Model = 'Value'
            $CsModelResource.Test() | Should -Be $false
         }
      }
   }

   Describe 'CsDomain' {
      BeforeAll {
         Mock Get-ComputerInfo { return @{CsDomain = 'TestDomain'; CsDomainRole = 'TestRole' } }
      }

      $script:CsDomainResource = [CsDomain]::new()

      It 'Get Current Property' -Tag 'Get' {
         $initialState = $CsDomainResource.Get()
         $initialState.Domain | Should -Be 'TestDomain'
         $initialState.Role | Should -Be 'TestRole'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Domain is specified and role is null should match' {
            $CsDomainResource.Domain = 'TestDomain'
            $CsDomainResource.Test() | Should -Be $true
         }
         It 'Domain is specified and role is null should not match' {
            $CsDomainResource.Domain = 'Domain'
            $CsDomainResource.Test() | Should -Be $false
         }
         It 'Domain and role specified should match' {
            $CsDomainResource.Domain = 'TestDomain'
            $CsDomainResource.Role = 'TestRole'
            $CsDomainResource.Test() | Should -Be $true
         }
         It 'Domain and role specified should not match' {
            $CsDomainResource.Domain = 'TestDomain'
            $CsDomainResource.Role = 'Role'
            $CsDomainResource.Test() | Should -Be $false
         }
      }
   }

   Describe 'PowerShellVersion' {
      BeforeAll {
         $script:OriginalPsVersion = $global:PSVersionTable.PSVersion
         $global:PSVersionTable.PSVersion = [System.Version]'7.2.0.0'
      }

      $script:PowerShellVersionResource = [PowerShellVersion]::new()

      It 'Get Current Property' -Tag 'Get' {
         $initialState = $PowerShellVersionResource.Get()
         [String]::IsNullOrEmpty($initialState.MinVersion) | Should -Be $true
         $initialState.PowerShellVersion | Should -Be '7.2.0.0'
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should succeed' {
            $PowerShellVersionResource.MinVersion = '7.2'
            $PowerShellVersionResource.Test() | Should -Be $true
         }
         It 'Should fail' {
            $PowerShellVersionResource.MinVersion = '7.2.1'
            $PowerShellVersionResource.Test() | Should -Be $false
         }
         It 'Should throw if MinVersion is not a version' {
            $PowerShellVersionResource.MinVersion = 'This is not a version'
            { $PowerShellVersionResource.Test() } | Should -Throw
         }
      }

      AfterAll {
         $global:PSVersionTable.PSVersion = $script:OriginalPsVersion
      }
   }


   Describe 'PnPDevice' {
      BeforeAll {

         $script:TestPnPDevice = @{
            FriendlyName = 'TestName'
            Class        = 'TestClass'
            Status       = 'OK'
         }

         # Mock when all parameters are present
         Mock Get-PnPDevice -ParameterFilter { $FriendlyName -eq 'TestName' -and $DeviceClass -eq 'TestClass' -and $Status -eq 'OK' } -MockWith { return $script:TestPnPDevice }
         # Mock when two parameters are present
         Mock Get-PnPDevice -ParameterFilter { $FriendlyName -eq 'TestName' -and $DeviceClass -eq 'TestClass' -and [String]::IsNullOrWhiteSpace($Status) } -MockWith { return $script:TestPnPDevice }
         # Mock when one parameter is present
         Mock Get-PnPDevice -ParameterFilter { $FriendlyName -eq 'TestName' -and [String]::IsNullOrWhiteSpace($DeviceClass) -and [String]::IsNullOrWhiteSpace($Status) } -MockWith { return $script:TestPnPDevice }
         # Catch-all Mock
         Mock Get-PnPDevice -ParameterFilter { } -MockWith { return @{ FriendlyName = $null; Class = $null; Status = 'UNKNOWN' } }
      }

      BeforeEach {
         # Because of the way the Status enum works, the instance of the resource needs to be re-created for each test
         $script:PnPDeviceResource = [PnPDevice]::new()
      }

      $script:PnPDeviceResource = [PnPDevice]::new()
      Context 'Get Current Property' -Tag 'Get' {
         It 'Should match a device with one property specified' {
            $PnPDeviceResource.FriendlyName = 'TestName'
            $initialState = $PnPDeviceResource.Get()
            $initialState.Ensure | Should -Be 'Present'
         }
         It 'Should match a device with two properties specified' {
            $PnPDeviceResource.FriendlyName = 'TestName'
            $PnPDeviceResource.DeviceClass = 'TestClass'
            $initialState = $PnPDeviceResource.Get()
            $initialState.Ensure | Should -Be 'Present'
         }
         It 'Should match a device with all properties specified' {
            $PnPDeviceResource.FriendlyName = 'TestName'
            $PnPDeviceResource.DeviceClass = 'TestClass'
            $PnPDeviceResource.Status = 'OK'
            $initialState = $PnPDeviceResource.Get()
            $initialState.Ensure | Should -Be 'Present'
         }
         It 'Should not match a device with bad FriendlyName' {
            $PnPDeviceResource.FriendlyName = 'Name'
            $initialState = $PnPDeviceResource.Get()
            $initialState.Ensure | Should -Be 'Absent'
         }
         It 'Should not match a device with bad status' {
            $PnPDeviceResource.FriendlyName = 'TestName'
            $PnPDeviceResource.DeviceClass = 'TestClass'
            $PnPDeviceResource.Status = 'ERROR'
            $initialState = $PnPDeviceResource.Get()
            $initialState.Ensure | Should -Be 'Absent'
         }
      }

      Context 'Test Current Property' -Tag 'Test' {
         It 'Should match a device with one property specified' {
            $PnPDeviceResource.FriendlyName = 'TestName'
            $PnPDeviceResource.Test() | Should -Be $true
         }
         It 'Should match a device with two properties specified' {
            $PnPDeviceResource.FriendlyName = 'TestName'
            $PnPDeviceResource.DeviceClass = 'TestClass'
            $PnPDeviceResource.Test() | Should -Be $true
         }
         It 'Should match a device with all properties specified' {
            $PnPDeviceResource.FriendlyName = 'TestName'
            $PnPDeviceResource.DeviceClass = 'TestClass'
            $PnPDeviceResource.Status = 'OK'
            $PnPDeviceResource.Test() | Should -Be $true
         }
         It 'Should not match a device with bad FriendlyName' {
            $PnPDeviceResource.FriendlyName = 'Name'
            $PnPDeviceResource.Status = 'OK'
            $PnPDeviceResource.Test() | Should -Be $false
         }
         It 'Should not match a device with bad status' {
            $PnPDeviceResource.FriendlyName = 'TestName'
            $PnPDeviceResource.DeviceClass = 'TestClass'
            $PnPDeviceResource.Status = 'ERROR'
            $PnPDeviceResource.Test() | Should -Be $false
         }
      }
   }
}


AfterAll {
}
