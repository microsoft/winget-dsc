---
external help file: Microsoft.Windows.Setting.Personalization.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Personalization
ms.date: 01/09/2025
online version:
schema: 2.0.0
title: BackgroundPicture
---

# BackgroundPicture

## SYNOPSIS

The `BackgroundPicture` class contains DSC resources for configuring the desktop background picture.

## DESCRIPTION

The `BackgroundPicture` class contains DSC resources for configuring the desktop background picture.

## PARAMETERS

| **Parameter**   | **Attribute**  | **DataType** | **Description**                                                                                                                                                      | **Allowed Values**                         |
| --------------- | -------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| Picture         | Key, Mandatory | String       | The path to the image file that will be used as the desktop background picture.                                                                                      | Any valid image path.                      |
| Style           | Optional       | String       | The style of the desktop background picture.                                                                                                                         | { Fill, Fit, Stretch, Tile, Center, Span } |
| BackgroundColor | Optional       | String       | The color of the desktop background. The value should be in the format `R,G,B`, where `R`, `G`, and `B` are the red, green, and blue color components, respectively. | Any RGB code in 0,0,0 format.              |

## EXAMPLES

### EXAMPLE 1 - Example to set the background picture, style and color

```powershell
Invoke-DscResource -Name BackgroundPicture -Method Set -Property @{ Picture = 'C:\Pictures\Background.jpg'; Style = 'Fill'; BackgroundColor = '255,255,255' }

# This example sets the desktop background picture to `C:\Pictures\Background.jpg` with the `Fill` style and white background color.
```
