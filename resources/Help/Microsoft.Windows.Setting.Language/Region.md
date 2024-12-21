---
external help file: Microsoft.Windows.Setting.Language.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Language
ms.date: 11/04/2024
online version:
schema: 2.0.0
title: Region
---

# Region

## SYNOPSIS

The `Region` DSC Resource allows you to set the region settings on your local Windows machine.

## DESCRIPTION

The `Region` DSC Resource allows you to set the region settings on your local Windows machine.

## PARAMETERS

| **Parameter**  | **Attribute**   | **DataType** | **Description**                                                                        | **Allowed Values**                                                                                                                                     |
| -------------- | --------------- | ------------ | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `GeoId`        | Mandatory       | String       | The geographical ID that represents the region. This is used to set the home location. | For a full list of geographical IDs, refer to the following link: https://learn.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations |
| `HomeLocation` | NonConfigurable | String       | The home location of the region. This is a read-only property.                         |                                                                                                                                                        |
| `Exist`        | Optional        | Boolean      | Indicates whether the language should exist. The default value is `$true`.             | `$true`, `$false`                                                                                                                                      |

## EXAMPLES

### EXAMPLE 1 - Set the region to United States

```powershell
Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Language -Name Region -Method Set -Property @{ GeoId = '244' }
```
