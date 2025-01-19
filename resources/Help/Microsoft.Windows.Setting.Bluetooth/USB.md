---
external help file: Microsoft.Windows.Setting.Bluetooth-Help.xml
Module Name: Microsoft.Windows.Setting.Bluetooth
ms.date: 01/19/2025
online version:
schema: 2.0.0
title: USB
---

# USB

## SYNOPSIS

The `USB` DSC Resource allows you to manage USB settings on Windows.

## DESCRIPTION

The `USB` DSC Resource allows you to manage USB settings on Windows.

## PARAMETERS

|       **Parameter**        | **Attribute** | **DataType** |                                 **Description**                                 | **Allowed Values** |
| -------------------------- | ------------- | ------------ | ------------------------------------------------------------------------------- | ------------------ |
| `SID`                      | Key           | String       | The security identifier. This is a key property and should not be set manually. |                    |
| `ConnectionNotifications`  | Optional      | Boolean      | Show a notification if there are issues connection to a USB device.             | `$true`, `$false`  |
| `SlowChargingNotification` | Optional      | Boolean      | Will show a notification if the PC is charging slowly over USB.                 | `$true`, `$false`  |
| `BatterySaver`             | Optional      | Boolean      | Stops USB devices from draining power when the screen is off.                   | `$true`, `$false`  |

## EXAMPLES

### EXAMPLE 1 - Disable notification when there are issues connection a USB device

```powershell
Invoke-DscResource -Name USB -Method Set -Property @{ ConnectionNotifications = $false }

# This example sets the `ConnectionNotifications` property to `$false`.
```
