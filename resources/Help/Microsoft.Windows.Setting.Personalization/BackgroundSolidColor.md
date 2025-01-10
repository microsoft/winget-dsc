---
external help file: Microsoft.Windows.Setting.Personalization.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Personalization
ms.date: 01/09/2025
online version:
schema: 2.0.0
title: BackgroundSolidColor
---

# BackgroundSolidColor

## SYNOPSIS

The `BackgroundSolidColor` class contains DSC resources for configuring the desktop background color.

## DESCRIPTION

The `BackgroundSolidColor` class contains DSC resources for configuring the desktop background color.

## PARAMETERS

| **Parameter**   | **Attribute**  | **DataType** | **Description**                                                                                                                                                      | **Allowed Values**                         |
| --------------- | -------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| BackgroundColor | Key, Mandatory   | String       | The color of the desktop background. The value should be in the format `R,G,B`, where `R`, `G`, and `B` are the red, green, and blue color components, respectively. | Any RGB code in 0,0,0 format.              |

## EXAMPLES

### EXAMPLE 1 - Example to set the background color

```powershell
Invoke-DscResource -Name BackgroundSolidColor -Method Set -Property @{ BackgroundColor = '255,255,255' }

# This example sets the desktop background color to white.
```
