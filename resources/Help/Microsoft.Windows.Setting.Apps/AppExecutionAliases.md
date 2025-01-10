---
external help file: Microsoft.Windows.Setting.Apps.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Apps
ms.date:  01/10/2025
online version:
schema: 2.0.0
title: AppExecutionAliases
---

# AppExecutionAliases

## SYNOPSIS

The `AppExecutionAliases` DSC Resource allows you to manage execution aliases for applications on Windows.

## DESCRIPTION

The `AppExecutionAliases` DSC Resource allows you to manage execution aliases for applications on Windows.

## PARAMETERS

|    **Parameter**     | **Attribute**  | **DataType** |                                            **Description**                                            |  **Allowed Values**   |
| -------------------- | -------------- | ------------ | ----------------------------------------------------------------------------------------------------- | --------------------- |
| `ExecutionAliasName` | Key, Mandatory | String       | The path to the image file that will be used as the desktop background picture.                       | Any valid image path. |
| `Exist`              | Optional       | Boolean      | Indicates whether the execution alias should exist. This is an optional parameter. Defaults to `True` | `True` or `False`     |

## EXAMPLES

### EXAMPLE 1 - Example that adds `myAppAlias.exe` as app execution alias

```powershell
Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name AppExecutionAliases -Method Set -Property @{
    ExecutionAliasName = 'myAppAlias.exe';
    Exist = $true;
}

# This example ensures that the execution alias 'myAppAlias.exe' exists.
```
