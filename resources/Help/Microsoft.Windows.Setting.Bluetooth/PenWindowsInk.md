---
external help file: Microsoft.Windows.Setting.Bluetooth-Help.xml
Module Name: Microsoft.Windows.Setting.Bluetooth
ms.date: 01/19/2025
online version:
schema: 2.0.0
title: PenWindowsInk
---

# PenWindowsInk

## SYNOPSIS

The `PenWindowsInk` class is a DSC resource that allows you to manage the Pen and Windows Ink settings on your Windows device.

## DESCRIPTION

The `PenWindowsInk` class is a DSC resource that allows you to manage the Pen and Windows Ink settings on your Windows device.

## PARAMETERS

|  **Parameter**   | **Attribute** | **DataType** |          **Description**          |   **Allowed Values**   |
| ---------------- | ------------- | ------------ | --------------------------------- | ---------------------- |
| `FingerTipFont`  | Key           | String       | The font used for the finger tip. | `InkFree` or `SegeoUI` |
| `WriteFingerTip` | Optional      | Boolean      | Enable inking with touch.         | `$true`, `$false`      |

## EXAMPLES

### EXAMPLE 1 - Sets the finger tip font to Segeo UI

```powershell
Invoke-DscResource -Name PenWindowsInk -Method Set -Property @{ FingerTipFont = 'SegoeUI' }

# This example sets the `FingerTipFont` property to `SegoeUI`.
```
