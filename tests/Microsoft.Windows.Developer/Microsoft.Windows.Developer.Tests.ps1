# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

<#
.Synopsis
   Pester tests related to the Microsoft.WinGet.Developer PowerShell module.
#>

BeforeAll {
   Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck
   Import-Module Microsoft.Windows.Developer

   # Helper function for calling Invoke-DscResource on the Microsoft.WinGet.DSC module.
   function InvokeWinGetDSC() {
       param (
           [Parameter()]
           [string]$Name,

           [Parameter()]
           [string]$Method,

           [Parameter()]
           [hashtable]$Property
       )

       return Invoke-DscResource -Name $Name -ModuleName Microsoft.WinGet.DSC -Method $Method -Property $Property
   }
}

Describe 'List available DSC resources'{
   It 'Shows DSC Resources'{
       $expectedDSCResources = "DeveloperMode", "OsVersion", "ShowSecondsInClock", "EnableDarkMode", "Taskbar", "UserAccessControl", "UserAccessControl"
       $availableDSCResources = (Get-DscResource -Module Microsoft.Windows.Developer).Name
       $availableDSCResources.length | Should -Be 7
       $availableDSCResources | Where-Object {$expectedDSCResources -notcontains $_} | Should -BeNullOrEmpty -ErrorAction Stop
   }
}


Describe 'Taskbar'{
   Before 'Get current state'{

   }

   It 'Get Taskbar state'{
      $currentState = Invoke-DscResource -Name Taskbar -ModuleName Microsoft.Windows.Developer -Method Get -Property {}
      $currentState.
   }
}