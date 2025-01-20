---
external help file: Microsoft.Windows.Setting.Bluetooth-Help.xml
Module Name: Microsoft.Windows.Setting.Bluetooth
ms.date: 01/19/2025
online version:
schema: 2.0.0
title: PrinterAndScanne
---

# PrinterAndScanne

## SYNOPSIS

The `PrinterAndScanner` class is a DSC resource that allows you to manage the printer and scanner settings on your Windows device.

## DESCRIPTION

The `PrinterAndScanner` class is a DSC resource that allows you to manage the printer and scanner settings on your Windows device.

## PARAMETERS

| **Parameter**                         | **Attribute** | **DataType** | **Description**                                                                 | **Allowed Values** |
| ------------------------------------- | ------------- | ------------ | ------------------------------------------------------------------------------- | ------------------ |
| `SID`                                 | Key           | String       | The security identifier. This is a key property and should not be set manually. | N/A                |
| `LetWindowsManageDefaultPrinter`      | Optional      | Boolean      | Let Windows manage the default printer.                                         | `$true`, `$false`  |
| `DriverDownloadOverMeteredConnection` | Optional      | Boolean      | Download drivers over a metered connection.                                     | `$true`, `$false`  |

.PARAMETER SID
    The security identifier. This is a key property and should not be set manually.

.PARAMETER LetWindowsManageDefaultPrinter
    Let Windows manage the default printer.

.PARAMETER DriverDownloadOverMeteredConnection
    Download drivers over a metered connection.

## EXAMPLES

### EXAMPLE 1 - Disable Windows from managing the default printer

```powershell
Invoke-DscResource -Name PrinterAndScanner -Method Set -Property @{ LetWindowsManageDefaultPrinter = $false }

# This example disables Windows from managing the default printer.
```
