---
external help file: Microsoft.Windows.Setting.Time.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Time
ms.date: 05/11/2024
online version:
schema: 2.0.0
title: Clock
---

# Clock

## SYNOPSIS

The `Clock` DSC Resource allows you to manage the system tray date/time visibility settings on a Windows machine.

## DESCRIPTION

The `Clock` DSC Resource allows you to manage the system tray date/time visibility settings on a Windows machine.

## PARAMETERS

| **Parameter**               | **Attribute** | **DataType** | **Description**                                                                                                    | **Allowed Values** |
| --------------------------- | ------------- | ------------ | ------------------------------------------------------------------------------------------------------------------ | ------------------ |
| `SID`                       | Key           | String       | The security identifier. This is a key property and should not be set manually.                                    | N/A                |
| `ShowSystemTrayClock`       | Optional      | Boolean      | Whether to show the date and time in the system tray. The value should be a boolean. The default value is `$true`. | `$true`, `$false`  |
| `NotifyClockChangeProperty` | Optional      | Boolean      | Whether to notify the user when the time changes. The value should be a boolean.                                   | `$true`, `$false`  |

## EXAMPLES

### EXAMPLE 1 - Get the current clock settings

```powershell
C:\> Invoke-DscResource -Name Clock -Method Get -Property {}

# This example gets the current clock settings on the machine.
```

### EXAMPLE 2 - Set system tray date and notify clock change

```powershell
Invoke-DscResource -Name Clock -Method Set -Property @{ ShowSystemTrayDateTime = $true; NotifyClockChange = $true }

# This example sets the system tray date/time visibility settings on the machine.
```
