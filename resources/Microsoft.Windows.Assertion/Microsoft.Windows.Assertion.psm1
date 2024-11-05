# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

enum Ensure {
    Present
    Absent
}

enum PnPDeviceState {
    OK
    ERROR
    DEGRADED
    UNKNOWN
}

[DSCResource()]
class OsEditionId {

    [DscProperty(Key)]
    [string] $RequiredEdition

    [DscProperty(NotConfigurable)]
    [string] $Edition

    [OsEditionId] Get() {
        $this.Edition = Get-ComputerInfo | Select-Object -ExpandProperty WindowsEditionId

        return @{
            RequiredEdition = $this.RequiredEdition
            Edition         = $this.Edition
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Edition -eq $currentState.RequiredEdition
    }

    [void] Set() {
        # This resource is only for asserting the Edition ID requirement.
    }
}

[DSCResource()]
class SystemArchitecture {

    [DscProperty(Key)]
    [string] $RequiredArchitecture

    [DscProperty(NotConfigurable)]
    [string] $Architecture

    [SystemArchitecture] Get() {
        $this.Architecture = Get-ComputerInfo | Select-Object -ExpandProperty OsArchitecture

        return @{
            RequiredArchitecture = $this.RequiredArchitecture
            Architecture         = $this.Architecture
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Architecture -eq $currentState.RequiredArchitecture
    }

    [void] Set() {
        # This resource is only for asserting the System Architecture requirement.
    }
}

[DSCResource()]
class ProcessorArchitecture {

    [DscProperty(Key)]
    [string] $RequiredArchitecture

    [DscProperty(NotConfigurable)]
    [string] $Architecture

    [ProcessorArchitecture] Get() {
        $this.Architecture = $env:PROCESSOR_ARCHITECTURE

        return @{
            RequiredArchitecture = $this.RequiredArchitecture
            Architecture         = $this.Architecture
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Architecture -eq $currentState.RequiredArchitecture
    }

    [void] Set() {
        # This resource is only for asserting the Processor Architecture requirement.
    }
}

[DSCResource()]
class HyperVisor {

    [DscProperty(Key)]
    [Ensure] $Ensure

    [HyperVisor] Get() {
        return @{
            Ensure = (Get-ComputerInfo | Select-Object -ExpandProperty HyperVisorPresent) ? [Ensure]::Present : [Ensure]::Absent
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        # This resource is only for asserting the presence of a HyperVisor.
    }
}

[DSCResource()]
class OsInstallDate {

    [DscProperty(Key)]
    [string] $Before = [System.DateTime]::Now

    [DscProperty()]
    [string] $After

    [DscProperty(NotConfigurable)]
    [string] $InstallDate

    [OsInstallDate] Get() {
        # Try-Catch isn't a good way to do this, but `[System.DateTimeOffset]::TryParse($this.Before, [ref]$parsedBefore)` is erroring
        try {
            $this.Before = $this.Before ? [System.DateTimeOffset]::Parse($this.Before) : $null
        } catch {
            throw "'$($this.Before)' is not a valid Date string."
        }

        # Try-Catch isn't a good way to do this, but `[System.DateTimeOffset]::TryParse($this.After, [ref]$parsedAfter)` is erroring
        try {
            $this.After = $this.After ? [System.DateTimeOffset]::Parse($this.After) : $null
        } catch {
            throw "'$($this.After)' is not a valid Date string."
        }

        $this.InstallDate = [System.DateTimeOffset]::Parse($(Get-ComputerInfo | Select-Object -ExpandProperty OsInstallDate))

        return @{
            Before      = $this.Before
            After       = $this.After
            InstallDate = $this.InstallDate
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        # this.Get() should always return [System.DateTimeOffset] or $null which can be compared directly
        # $null should always be treated as less than a [System.DateTimeOffset]
        return ($currentState.InstallDate -gt $currentState.After) -and ($currentState.InstallDate -lt $currentState.Before)
    }

    [void] Set() {
        # This resource is only for asserting the OS Install Date.
    }
}

# This is the same function from Microsoft.Windows.Developer, just included here as it seemed to make sense
[DSCResource()]
class OsVersion {

    [DscProperty(Key)]
    [string] $MinVersion

    [DscProperty(NotConfigurable)]
    [string] $OsVersion

    [OsVersion] Get() {
        $parsedVersion = $null
        if (![System.Version]::TryParse($this.MinVersion, [ref]$parsedVersion)) {
            throw "'$($this.MinVersion)' is not a valid Version string."
        }

        $this.OsVersion = Get-ComputerInfo | Select-Object -ExpandProperty OsVersion

        return @{
            MinVersion = $this.MinVersion
            OsVersion  = $this.OsVersion
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return [System.Version]$currentState.OsVersion -ge [System.Version]$currentState.MinVersion
    }

    [void] Set() {
        # This resource is only for asserting the os version requirement.
    }
}

[DSCResource()]
class CsManufacturer {

    [DscProperty(Key)]
    [string] $RequiredManufacturer

    [DscProperty(NotConfigurable)]
    [string] $Manufacturer

    [CsManufacturer] Get() {
        $this.Manufacturer = Get-ComputerInfo | Select-Object -ExpandProperty CsManufacturer

        return @{
            RequiredManufacturer = $this.RequiredManufacturer
            Manufacturer         = $this.Manufacturer
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Manufacturer -eq $currentState.RequiredManufacturer
    }

    [void] Set() {
        # This resource is only for asserting the Computer Manufacturer requirement.
    }
}

[DSCResource()]
class CsModel {

    [DscProperty(Key)]
    [string] $RequiredModel

    [DscProperty(NotConfigurable)]
    [string] $Model

    [CsModel] Get() {
        $this.Model = Get-ComputerInfo | Select-Object -ExpandProperty CsModel

        return @{
            RequiredModel = $this.RequiredModel
            Model         = $this.Model
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Model -eq $currentState.RequiredModel
    }

    [void] Set() {
        # This resource is only for asserting the Computer Model requirement.
    }
}

[DSCResource()]
class CsDomain {

    [DscProperty(Key)]
    [string] $RequiredDomain

    [DscProperty()]
    [string] $RequiredRole

    [DscProperty(NotConfigurable)]
    [string] $Domain

    [DscProperty(NotConfigurable)]
    [string] $Role

    [CsDomain] Get() {
        $domainInfo = Get-ComputerInfo | Select-Object -Property CsDomain, CsDomainRole
        $this.Domain = $domainInfo.CsDomain
        $this.Role = $domainInfo.CsDomainRole

        return @{
            RequiredDomain = $this.RequiredDomain
            Domain         = $this.Domain
            RequiredRole   = $this.RequiredRole
            Role           = $this.Role
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($currentState.Domain -ne $currentState.RequiredDomain) { return $false } # If domains don't match
        if (!$currentState.RequiredRole) { return $true } # RequiredRole is null and domains match
        return ($currentState.RequiredRole -eq $currentState.Role) # Return whether the roles match
    }

    [void] Set() {
        # This resource is only for asserting the Computer Domain requirement.
    }
}

[DSCResource()]
class PowerShellVersion {

    [DscProperty(Key)]
    [string] $MinVersion

    [DscProperty(NotConfigurable)]
    [string] $PowerShellVersion

    [PowerShellVersion] Get() {
        $parsedVersion = $null
        if (![System.Version]::TryParse($this.MinVersion, [ref]$parsedVersion)) {
            throw "'$($this.MinVersion)' is not a valid Version string."
        }

        $this.PowerShellVersion = $global:PSVersionTable.PSVersion

        return @{
            MinVersion        = $this.MinVersion
            PowerShellVersion = $this.PowerShellVersion
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return [System.Version]$currentState.PowerShellVersion -ge [System.Version]$currentState.MinVersion
    }

    [void] Set() {
        # This resource is only for asserting the PowerShell version requirement.
    }
}

[DSCResource()]
class PnPDevice {

    [DscProperty(Key)]
    [Ensure] $Ensure

    [DscProperty(Mandatory)]
    [string[]] $FriendlyName

    [DscProperty()]
    [string[]] $DeviceClass

    [DscProperty()]
    [PnPDeviceState[]] $Status

    [PnPDevice] Get() {
        $params = @{}
        $params += $this.FriendlyName ? @{FriendlyName = $this.FriendlyName } : @{}
        $params += $this.DeviceClass ? @{Class = $this.DeviceClass } : @{}
        $params += $this.Status ? @{Status = $this.Status } : @{}

        $pnpDevice = @(Get-PnpDevice @params)

        # It's possible that multiple PNP devices match, but as long as one matches then the assertion succeeds
        return @{
            Ensure       = $pnpDevice ? [Ensure]::Present : [Ensure]::Absent
            FriendlyName = $this.FriendlyName
            DeviceClass  = $this.DeviceClass
            Status       = $this.Status
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        return ($currentState.Ensure -eq $this.Ensure)
    }

    [void] Set() {
        # This resource is only for asserting the PnP Device requirement.
    }
}
