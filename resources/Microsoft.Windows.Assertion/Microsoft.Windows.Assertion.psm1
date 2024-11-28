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
    [string] $Edition

    [OsEditionId] Get() {
        $currentState = [OsEditionId]::new()
        $currentState.Edition = Get-ComputerInfo | Select-Object -ExpandProperty WindowsEditionId
        return $currentState
    }

    [bool] Test() {
        return $this.Get().Edition -eq $this.Edition
    }

    [void] Set() {
        # This resource is only for asserting the Edition ID requirement.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. Expected '$($this.Edition)' but received '$($this.Get().Edition)'")
    }
}

[DSCResource()]
class SystemArchitecture {

    [DscProperty(Key)]
    [string] $Architecture

    [SystemArchitecture] Get() {
        $currentState = [SystemArchitecture]::new()
        $currentState.Architecture = Get-ComputerInfo | Select-Object -ExpandProperty OsArchitecture
        return $currentState
    }

    [bool] Test() {
        return $this.Get().Architecture -eq $this.Architecture
    }

    [void] Set() {
        # This resource is only for asserting the System Architecture requirement.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. Expected '$($this.Architecture)' but received '$($this.Get().Architecture)'")
    }
}

[DSCResource()]
class ProcessorArchitecture {

    [DscProperty(Key)]
    [string] $Architecture

    [ProcessorArchitecture] Get() {
        $currentState = [ProcessorArchitecture]::new()
        $currentState.Architecture = $env:PROCESSOR_ARCHITECTURE
        return $currentState
    }

    [bool] Test() {
        return $this.Get().Architecture -eq $this.Architecture
    }

    [void] Set() {
        # This resource is only for asserting the Processor Architecture requirement.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. Expected '$($this.Architecture)' but received '$($this.Get().Architecture)'")
    }
}

[DSCResource()]
class HyperVisor {

    [DscProperty(Key)]
    [Ensure] $Ensure

    [HyperVisor] Get() {
        $currentState = [HyperVisor]::new()
        $currentState.Ensure = (Get-ComputerInfo | Select-Object -ExpandProperty HyperVisorPresent) ? [Ensure]::Present : [Ensure]::Absent
        return $currentState
    }

    [bool] Test() {
        return $this.Get().Ensure -eq $this.Ensure
    }

    [void] Set() {
        # This resource is only for asserting the presence of a HyperVisor.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. Expected '$($this.Ensure)' but received '$($this.Get().Ensure)'")
    }
}

[DSCResource()]
class OsInstallDate {

    [DscProperty(Key)]
    [string] $Before

    [DscProperty()]
    [string] $After

    [DscProperty(NotConfigurable)]
    [string] $InstallDate

    [OsInstallDate] Get() {
        $currentState = [OsInstallDate]::new()

        # Try-Catch isn't a good way to do this, but `[System.DateTimeOffset]::TryParse($this.Before, [ref]$parsedBefore)` is erroring
        try {
            if ($this.Before) { [System.DateTimeOffset]::Parse($this.Before) }
        } catch {
            throw "'$($this.Before)' is not a valid Date string."
        }

        # Try-Catch isn't a good way to do this, but `[System.DateTimeOffset]::TryParse($this.After, [ref]$parsedAfter)` is erroring
        try {
            if ($this.After) { [System.DateTimeOffset]::Parse($this.After) }
        } catch {
            throw "'$($this.After)' is not a valid Date string."
        }

        $currentState.Before = $this.Before
        $currentState.After = $this.After
        $currentState.InstallDate = Get-ComputerInfo | Select-Object -ExpandProperty OsInstallDate
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($this.Before -and [System.DateTimeOffset]$currentState.InstallDate -gt [System.DateTimeOffset]$this.Before) { return $false } # The InstallDate was later than the specified 'Before' date
        if ($this.After -and [System.DateTimeOffset]$currentState.InstallDate -lt [System.DateTimeOffset]$this.After) { return $false } # The InstallDate was earlier than the specified 'After' date
        return $true
    }

    [void] Set() {
        # This resource is only for asserting the OS Install Date.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. '$($this.Before)' >= '$($this.Get().InstallDate)' >= '$($this.After)' evaluated to 'False'")
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

        if ($this.MinVersion -and ![System.Version]::TryParse($this.MinVersion, [ref]$null)) {
            throw "'$($this.MinVersion)' is not a valid Version string."
        }

        $currentState = [OsVersion]::new()
        $currentState.MinVersion = $this.MinVersion
        $currentState.OsVersion = Get-ComputerInfo | Select-Object -ExpandProperty OsVersion
        return $currentState
    }

    [bool] Test() {
        return [System.Version]$this.Get().OsVersion -ge [System.Version]$this.MinVersion
    }

    [void] Set() {
        # This resource is only for asserting the os version requirement.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. '$($this.Get().OsVersion)' >= '$($this.MinVersion)' evaluated to 'False'")
    }
}

[DSCResource()]
class CsManufacturer {

    [DscProperty(Key)]
    [string] $Manufacturer

    [CsManufacturer] Get() {
        $currentState = [CsManufacturer]::new()
        $currentState.Manufacturer = Get-ComputerInfo | Select-Object -ExpandProperty CsManufacturer
        return $currentState
    }

    [bool] Test() {
        return $this.Get().Manufacturer -eq $this.Manufacturer
    }

    [void] Set() {
        # This resource is only for asserting the Computer Manufacturer requirement.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. Expected '$($this.Manufacturer)' but received '$($this.Get().Manufacturer)'")
    }
}

[DSCResource()]
class CsModel {

    [DscProperty(Key)]
    [string] $Model

    [CsModel] Get() {
        $currentState = [CsModel]::new()
        $currentState.Model = Get-ComputerInfo | Select-Object -ExpandProperty CsModel
        return $currentState
    }

    [bool] Test() {
        return $this.Get().Model -eq $this.Model
    }

    [void] Set() {
        # This resource is only for asserting the Computer Model requirement.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. Expected '$($this.Model)' but received '$($this.Get().Model)'")
    }
}

[DSCResource()]
class CsDomain {

    [DscProperty(Key)]
    [string] $Domain

    [DscProperty()]
    [string] $Role

    [CsDomain] Get() {
        $domainInfo = Get-ComputerInfo | Select-Object -Property CsDomain, CsDomainRole

        $currentState = [CsDomain]::new()
        $currentState.Domain = $domainInfo.CsDomain
        $currentState.Role = $domainInfo.CsDomainRole
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($currentState.Domain -ne $this.Domain) { return $false } # If domains don't match
        if (!$this.Role) { return $true } # Required Role is null and domains match
        return ($currentState.Role -eq $this.Role) # Return whether the roles match
    }

    [void] Set() {
        # This resource is only for asserting the Computer Domain requirement.
        if ($this.Test()) { return }
        $currentState = $this.Get()
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. Expected '$($this.Domain)<$($this.Role)>' but received '$($currentState.Domain)<$($currentState.Role)>'")
    }
}

[DSCResource()]
class PowerShellVersion {

    [DscProperty(Key)]
    [string] $MinVersion

    [DscProperty(NotConfigurable)]
    [string] $PowerShellVersion

    [PowerShellVersion] Get() {

        if ($this.MinVersion -and ![System.Version]::TryParse($this.MinVersion, [ref]$null)) {
            throw "'$($this.MinVersion)' is not a valid Version string."
        }

        $currentState = [PowerShellVersion]::new()
        $currentState.MinVersion = $this.MinVersion
        $currentState.PowerShellVersion = $global:PSVersionTable.PSVersion
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return [System.Version]$currentState.PowerShellVersion -ge [System.Version]$currentState.MinVersion
    }

    [void] Set() {
        # This resource is only for asserting the PowerShell version requirement.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New("Assertion Failed. '$($this.Get().PowerShellVersion)' >= '$($this.MinVersion)' evaluated to 'False'")
    }
}

[DSCResource()]
class PnPDevice {

    [DscProperty(Key)]
    [Ensure] $Ensure

    [DscProperty()]
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
        $currentState = [PnPDevice]::new()
        $currentState.Ensure = $pnpDevice ? [Ensure]::Present : [Ensure]::Absent
        $currentState.FriendlyName = $this.FriendlyName
        $currentState.DeviceClass = $this.DeviceClass
        $currentState.Status = $this.Status
        return $currentState
    }

    [bool] Test() {
        return $this.Get().Ensure -eq $this.Ensure
    }

    [void] Set() {
        # This resource is only for asserting the PnP Device requirement.
        if ($this.Test()) { return }
        throw [System.Configuration.ConfigurationException]::New('Assertion Failed. ' +
            $( if ($this.Ensure -eq [Ensure]::Present) {
                    'No PnP devices found which matched the parameters'
                } else {
                    'One or more PnP devices found which matched the parameters'
                }
            )
        )
    }
}
