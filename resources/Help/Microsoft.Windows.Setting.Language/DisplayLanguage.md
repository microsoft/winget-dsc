---
external help file: Microsoft.Windows.Setting.Language.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Language
ms.date: 11/04/2024
online version:
schema: 2.0.0
title: DisplayLanguage
---

# DisplayLanguage

## SYNOPSIS

The `DisplayLanguage` DSC Resource allows you to set the display language on your local Windows machine.

## DESCRIPTION

The `DisplayLanguage` DSC Resource allows you to set the display language on your local Windows machine.

## PARAMETERS

| **Parameter** | **Attribute** | **DataType** | **Description**                                                                                                                           | **Allowed Values**                                                               |
| ------------- | ------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `LocaleName`  | Mandatory     | String       | The name of the language. This is the language tag that represents the language. For example, `en-US` represents English (United States). | Use the `Get-WinUserLanguageList` to see what language pack have been installed. |
| `Exist`       | Optional      | Boolean      | Indicates whether the extension should exist. The default value is `$true`.                                                               | `$true`, `$false`                                                                |

## EXAMPLES

### EXAMPLE 1

```powershell
$params = @{
    LocaleName = 'en-US'
}
Invoke-DscResource -Name DisplayLanguage -Method Set -Property $params -ModuleName Microsoft.Windows.Setting.Language
```
