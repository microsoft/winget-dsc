---
external help file: Microsoft.Windows.Setting.Bluetooth-Help.xml
Module Name: Microsoft.Windows.Setting.Bluetooth
ms.date: 01/19/2025
online version:
schema: 2.0.0
title: AutoPlay
---

# MobileDevice

## SYNOPSIS

The `AutoPlay` class is a DSC resource that allows you to manage the AutoPlay settings on your Windows device.

## DESCRIPTION

The `AutoPlay` class is a DSC resource that allows you to manage the AutoPlay settings on your Windows device.

## PARAMETERS

| **Parameter**           | **Attribute** | **DataType** | **Description**                                                                 | **Allowed Values**                                                                                                                                                                |
| ----------------------- | ------------- | ------------ | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SID`                   | Key           | String       | The security identifier. This is a key property and should not be set manually. |                                                                                                                                                                                   |
| `AutoPlay`              | Optional      | Boolean      | Enable or disable AutoPlay.                                                     | `$true`, `$false`                                                                                                                                                                 |
| `RemovableDriveDefault` | Optional      | String       | The default auto play action for removable drives.                              | Either any of the following values: `KeepCurrentValue`, `MSStorageSense`, `MSTakeNoAction`, `MSOpenFolder`, `MSPromptEachTime`                                                    |
| `MemoryCardDefault`     | Optional      | String       | The default auto play action for memory cards.                                  | Either any of the following values: `KeepCurrentValue`, `MSPlayMediaOnArrival`, `MSTakeNoAction`, `MSOpenFolder`, `MSPromptEachTime`, `OneDriveAutoPlay`, `ImportPhotosAndVideos` |

## EXAMPLES

### EXAMPLE 1 - Disable auto play for all media and devices

```powershell
Invoke-DscResource -Name AutoPlay -Method Set -Property @{ AutoPlay = $false }

# This example disables the AutoPlay feature.
```
