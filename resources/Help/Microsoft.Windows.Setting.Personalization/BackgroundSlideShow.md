---
external help file: Microsoft.Windows.Setting.Personalization.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Personalization
ms.date: 01/09/2025
online version:
schema: 2.0.0
title: BackgroundSlideShow
---

# BackgroundSlideShow

## SYNOPSIS

The `BackgroundSlideShow` class contains DSC resources for configuring the desktop background slideshow.

## DESCRIPTION

The `BackgroundSlideShow` class contains DSC resources for configuring the desktop background slideshow.

## PARAMETERS

| **Parameter**    | **Attribute** | **DataType** | **Description**                                                                   | **Allowed Values**                                                                   |
| ---------------- | ------------- | ------------ | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `PictureAlbum`   | Key           | String       | The path to the folder containing the images for the slideshow.                   |                                                                                      |
| `SlideDuration`  | Optional      | Integer      | The duration for each slide in milliseconds. Defaults to 30 minutes.              | Valid values are '60000', '600000', '1800000', '3600000', '21600000', and '86400000' |
| `Shuffle`        | Optional      | Boolean      | Indicates whether the slideshow should shuffle the images.                        | `True` or `False`                                                                    |
| `PauseOnBattery` | Optional      | Boolean      | Indicates whether the slideshow should pause when the device is on battery power. | `True` or `False`                                                                    |
| `Style`          | Optional      | String       | The style of the desktop background picture.                                      | { Fill, Fit, Stretch, Tile, Center, Span }                                           |

## EXAMPLES

### EXAMPLE 1 - Example setting all properties with slide duration on 1 hour

```powershell
Invoke-DscResource -Name BackgroundSlideShow -Method Set -Property @{ PictureAlbum = 'C:\Pictures\Album'; SlideDuration = '1800000'; Shuffle = $true; PauseOnBattery = $true; Style = 'Fill' }

# This example sets the desktop background slideshow to use images from `C:\Pictures\Album` with a slide duration of 30 minutes, shuffling enabled, pausing on battery, and the `Fill` style.
```
