---
external help file: Microsoft.Windows.Setting.Apps.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Apps
ms.date:  01/10/2025
online version:
schema: 2.0.0
title: OfflineMap
---

# OfflineMap

## SYNOPSIS

The `OfflineMap` DSC Resource allows you to manage offline maps on Windows.

## DESCRIPTION

The `OfflineMap` DSC Resource allows you to manage offline maps on Windows.

## PARAMETERS

|    **Parameter**     | **Attribute**  | **DataType** |                                            **Description**                                            |  **Allowed Values**   |
| -------------------- | -------------- | ------------ | ----------------------------------------------------------------------------------------------------- | --------------------- |
| `OfflineMap` | Key, Mandatory | String       | The name of the offline map.                      | Any valid map address located from Settings -> Apps -> Offline maps |
| `Exist`              | Optional       | Boolean      | Indicates whether the offline map should exist. Defaults to `True` | `True` or `False`     |

## EXAMPLES

### EXAMPLE 1 - Install map for France offline

```powershell
Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name OfflineMap -Method Set -Property @{
	DownloadMap = 'France';
	Exist = $true;
}

# This example ensures that the offline map of France exists on your local machine.
```
