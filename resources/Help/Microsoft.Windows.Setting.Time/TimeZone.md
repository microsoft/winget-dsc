---
external help file: Microsoft.Windows.Setting.Time.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Time
ms.date: 05/11/2024
online version:
schema: 2.0.0
title: TimeZone
---

# Time

## SYNOPSIS

This `TimeZone` DSC Resource allows you to manage the time zone, automatic time zone update, and system tray date/time visibility settings on a Windows machine.

## DESCRIPTION

This `TimeZone` DSC Resource allows you to manage the time zone, automatic time zone update, and system tray date/time visibility settings on a Windows machine.

## PARAMETERS

| **Parameter**              | **Attribute** | **DataType** | **Description**                                                                                                                                                                                                                                                                            | **Allowed Values**                                                |
| -------------------------- | ------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------- |
| `Id`                       | Key           | String       | Specifies the time zone to set on the machine.                                                                                                                                                                                                                                             | Any valid time zone identifier from `Get-TimeZone -ListAvailable` |
| `SetTimeZoneAutomatically` | Optional      | Boolean      | Whether to set the time zone automatically. The value should be a boolean. You can find the setting in `Settings -> Time & Language -> Date & Time -> Set time zone automatically.                                       |     `$true`, `$false`                                          |
| `SetTimeAutomatically`     | Optional      | Boolean      | Whether to set the time automatically. The value should be a boolean. You can find the setting in `Settings -> Time & Language -> Date & Time -> Set time automatically.                                       |     `$true`, `$false`                                          |
| `AdjustForDayLightSaving`  | Optional      | Boolean      | Whether to adjust for daylight saving time. The value should be a boolean. You can find the setting in `Settings -> Time & Language -> Date & Time -> Adjust for daylight saving time automatically. | `$true`, `$false`                  |

## EXAMPLES

### EXAMPLE 1 - Set time zone to Pacific Standard Time

```powershell
Invoke-DscResource -Name TimeZone -ModuleName Microsoft.Windows.Setting.Time -Method Set -Property @{ Id = "Pacific Standard Time"}

# This example sets the time zone to Pacific Standard Time.
```

### EXAMPLE 2 - Get current time zone

```powershell
Invoke-DscResource -Name Time -Method Get -Property {}

# This example gets the current time settings on the machine.
```
