---
external help file: Microsoft.Windows.Assertion.psm1-Help.xml
Module Name: Microsoft.Windows.Assertion
ms.date: 11/2/2024
online version:
schema: 2.0.0
title: PnPDevice
---

# PnPDevice

## SYNOPSIS

Ensures at least one PnP Device is connected which matches the required parameters

## DESCRIPTION

The `PnPDevice` DSC Resource allows you to check for specific PnP Devices on the system as a pre-requisite for invoking other DSC Resources. This resource does not have the capability to modify PnP Device information.

## PARAMETERS

**Parameter**|**Attribute**|**DataType**|**Description**|**Allowed Values**
:-----|:-----|:-----|:-----|:-----
`FriendlyName`|Optional|String[]|The name of the PnP Device to be found|
`DeviceClass`|Optional|String[]|The PnP Class of the PnP Device to be found.| For example: `Display` or `Keyboard` or `PrintQueue`
`Status`|Optional|String]]|The current status of the PnP Device to be found|`OK`, `ERROR`, `DEGRADED`, `UNKNOWN`

## EXAMPLES

### Example 1

```powershell
# Check that a device with a specific name is connected
$params = @{
    FriendlyName = 'NVIDIA RTX A1000 Laptop GPU'
}
Invoke-DscResource -Name PnPDevice -Method Test -Property $params -ModuleName Microsoft.Windows.Assertion
```

### EXAMPLE 2

```powershell
# Check that any PnP Device is in the error state
$params = @{
    Status = 'ERROR'
}
Invoke-DscResource -Name PnPDevice -Method Test -Property $params -ModuleName Microsoft.Windows.Assertion
```

### EXAMPLE 3

```powershell
# Check that any Keyboard or Mouse is in the error state
$params = @{
    DeviceClass = @('Keyboard'; 'Mouse')
    Status = 'ERROR'
}
Invoke-DscResource -Name PnPDevice -Method Test -Property $params -ModuleName Microsoft.Windows.Assertion
```

### EXAMPLE 4

```powershell
# Check that a specific device is operational
$params = @{
    FriendlyName = 'Follow-You-Printing'
    DeviceClass = 'PrintQueue'
    Status = 'OK'
}
Invoke-DscResource -Name PnPDevice -Method Test -Property $params -ModuleName Microsoft.Windows.Assertion
```
