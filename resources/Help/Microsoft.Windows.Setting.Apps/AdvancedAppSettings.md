---
external help file: Microsoft.Windows.Setting.Apps.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Apps
ms.date:  01/10/2025
online version:
schema: 2.0.0
title: AdvancedAppSettings
---

# AppExecutionAliases

## SYNOPSIS

The `AdvancedAppSettings` DSC Resource allows you to manage advanced application settings on Windows, including app source preferences, device experience sharing, and app archiving.

## DESCRIPTION

The `AdvancedAppSettings` DSC Resource allows you to manage advanced application settings on Windows, including app source preferences, device experience sharing, and app archiving.

## PARAMETERS

| **Parameter**           | **Attribute** | **DataType** | **Description**                                                                 | **Allowed Values**                                    |
|-------------------------|---------------|--------------|---------------------------------------------------------------------------------|-------------------------------------------------------|
| `SID`                   | Key           | String       | The security identifier. This is a key property and should not be set manually. | N/A                                                   |
| `AppSourcePreference`   | Optional      | String       | Specifies the source preference for installing applications.                    | { Anywhere, Recommendations, PreferStore, StoreOnly } |
| `ShareDeviceExperience` | Optional      | String       | Specifies the device experience sharing setting.                                | { Off, Device, Everyone }                             |
| `ArchiveApp`            | Optional      | Boolean      | Indicates whether to enable app archiving.                                      | `True` or `False`                                     |

## EXAMPLES

### EXAMPLE 1 - Example that adds `myAppAlias.exe` as app execution alias

```powershell
Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name AppExecutionAliases -Method Set -Property @{
    ExecutionAliasName = 'myAppAlias.exe';
    Exist = $true;
}

# This example ensures that the execution alias 'myAppAlias.exe' exists.
```
