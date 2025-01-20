---
external help file: Microsoft.Windows.Setting.Bluetooth-Help.xml
Module Name: Microsoft.Windows.Setting.Bluetooth
ms.date: 01/19/2025
online version:
schema: 2.0.0
title: MobileDevices
---

# MobileDevices

## SYNOPSIS

The `MobileDevices` class is a DSC resource that allows you to manage the mobile devices settings on your Windows device.

## DESCRIPTION

The `MobileDevices` class is a DSC resource that allows you to manage the mobile devices settings on your Windows device.

## PARAMETERS

|       **Parameter**        | **Attribute** | **DataType** |                                 **Description**                                 | **Allowed Values** |
| -------------------------- | ------------- | ------------ | ------------------------------------------------------------------------------- | ------------------ |
| `SID`                      | Key           | String       | The security identifier. This is a key property and should not be set manually. |                    |
| `AccessMobileDevice`  | Optional      | Boolean      | Allow this PC to access the mobile device.             | `$true`, `$false`  |
| `PhoneLinkAccess` | Optional      | Boolean      | Allow access to Phone Link. For more information: https://support.microsoft.com/en-us/phone-link                 | `$true`, `$false`  |
| `ShowMobileDeviceSuggestions`             | Optional      | Boolean      | Show mobile device suggestions.                   | `$true`, `$false`  |

## EXAMPLES

### EXAMPLE 1 - Allow your PC to access your mobile device

```powershell
Invoke-DscResource -Name MobileDevices -Method Set -Property @{ AccessMobileDevice = $true }

# This example allows your mobile devices to be accessed by your PC.
```
