---
external help file: Microsoft.Windows.Setting.Time.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Time
ms.date: 05/11/2024
online version:
schema: 2.0.0
title: Time
---

# Time

## SYNOPSIS

This `Time` DSC Resource allows you to manage the time zone, automatic time zone update, and system tray date/time visibility settings on a Windows machine.

## DESCRIPTION

This `Time` DSC Resource allows you to manage the time zone, automatic time zone update, and system tray date/time visibility settings on a Windows machine.

## PARAMETERS

| **Parameter**              | **Attribute** | **DataType** | **Description**                                                                      | **Allowed Values**                                                |
| -------------------------- | ------------- | ------------ | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------- |
| `TimeZone`                 | Key           | String       | Specifies the time zone to set on the machine.                                       | Any valid time zone identifier from `Get-TimeZone -ListAvailable` |
| `SetTimeZoneAutomatically` | Optional      | Boolean      | The method to use to set the time zone automatically. The value should be a boolean. | `$true`, `$false`                                                 |


## EXAMPLES

### EXAMPLE 1 - Set time zone to Pacific Standard Time

```powershell
Invoke-DscResource -Name Time -Method Set -Property @{ TimeZone = "Pacific Standard Time"}

# This example sets the time zone to Pacific Standard Time.
```

### EXAMPLE 2

```powershell
Invoke-DscResource -Name Time -Method Get -Property {}

# This example gets the current time settings on the machine.
```