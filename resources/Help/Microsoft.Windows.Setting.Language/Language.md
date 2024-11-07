---
external help file: Microsoft.Windows.Setting.Language.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Language
ms.date: 11/04/2024
online version:
schema: 2.0.0
title: Language
---

# Language

## SYNOPSIS

The `Language` DSC Resource allows you to install, update, and uninstall languages on your local Windows machine.

## DESCRIPTION

The `Language` DSC Resource allows you to install, update, and uninstall languages on your local Windows machine.

## PARAMETERS

| **Parameter** | **Attribute** | **DataType** | **Description**                                                                                                                           | **Allowed Values**                                                                    |
| ------------- | ------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `LocaleName`  | Mandatory     | String       | The name of the language. This is the language tag that represents the language. For example, `en-US` represents English (United States). | Use the `Get-LocaleList` function or Export() method to get a list of allowed values. |
| `Exist`       | Optional      | Boolean      | Indicates whether the language should exist. The default value is `$true`.                                                               | `$true`, `$false`                                                                     |

## EXAMPLES

### EXAMPLE 1

```powershell
$params = @{
    LocaleName = 'en-US'
}
Invoke-DscResource -Name Language -Method Set -Property $params -ModuleName Microsoft.Windows.Setting.Language
```
