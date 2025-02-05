---
external help file: Microsoft.Windows.Setting.Apps.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Apps
ms.date:  01/10/2025
online version:
schema: 2.0.0
title: AppsForWebsites
---

# AppsForWebsites

## SYNOPSIS

The `AppsForWebsites` DSC Resource allows you to manage application associations for websites on Windows.

## DESCRIPTION

The `AppsForWebsites` DSC Resource allows you to manage application associations for websites on Windows.

## PARAMETERS

| **Parameter** | **Attribute**  | **DataType** | **Description**                                                                             | **Allowed Values**                                   |
| ------------- | -------------- | ------------ | ------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `LinkUri`     | Key, Mandatory | String       | The link URI.                                                                               | Any valid URI that is associated with an URI handler |
| `Exist`       | Optional       | Boolean      | Indicates whether the application association should be turned on or off. Default is `True` | `True` or `False`                                    |

## EXAMPLES

### EXAMPLE 1 - Turn off Adobe Acrobat to open links in the app

```powershell
Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name AppsForWebsites -Method Set -Property @{
	LinkUri = 'acrobat.adobe.com'
	Exist = $false
}

# This example ensures that the application association for 'acrobat.adobe.com' is turned off.
```
