---
external help file: Microsoft.Windows.Setting.Personalization.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Personalization
ms.date: 01/09/2025
online version:
schema: 2.0.0
title: BackgroundWindowsSpotlight
---

# BackgroundWindowsSpotlight

## SYNOPSIS

The `BackgroundWindowsSpotlight` class contains DSC resources for configuring the Windows Spotlight feature.

## DESCRIPTION

The `BackgroundWindowsSpotlight` class contains DSC resources for configuring the Windows Spotlight feature.

## PARAMETERS

| **Parameter**            | **Attribute**  | **DataType** | **Description**                                                                 | **Allowed Values** |
| ------------------------ | -------------- | ------------ | ------------------------------------------------------------------------------- | ------------------ |
| `SID`                    | Key, Mandatory | String       | The security identifier. This is a key property and should not be set manually. |                    |
| `EnableWindowsSpotlight` | Optional       | Boolean      | Indicates whether the Windows Spotlight feature should be enabled.              | `True` or `False`  |

## EXAMPLES

### EXAMPLE 1 - Example turning on Windows Spotlight background feature

```powershell
Invoke-DscResource -Name BackgroundWindowsSpotlight -Method Set -Property @{ EnableWindowsSpotlight = $true }

# This example enables the Windows Spotlight feature.
```
