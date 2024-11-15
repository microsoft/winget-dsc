---
external help file: Microsoft.Windows.Setting.Privacy.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Privacy
ms.date: 11/04/2024
online version:
schema: 2.0.0
title: Privacy
---

# Privacy

## SYNOPSIS

The `Privacy` DSC Resource allows you to manage Windows privacy settings. This resource ensures that the specified privacy settings are in the desired state on your local machine.

## DESCRIPTION

The `Privacy` DSC Resource allows you to manage Windows privacy settings. This resource ensures that the specified privacy settings are in the desired state on your local machine.

## PARAMETERS

| **Parameter**                      | **Attribute** | **DataType** | **Description**                                                                                                                                                                                                                                                               | **Allowed Values** |
| ---------------------------------- | ------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| `SID`                              | Key           | String       | The security identifier. This is a key property and should not be set manually.                                                                                                                                                                                               | N/A                |
| `EnablePersonalizedAds`            | Optional      | Boolean      | Indicates whether personalized ads should be enabled. The default value is `$null`. You can find the setting in `Settings > Privacy & security > General -> Let apps show me personalized ads by using my advertising ID.                      | `$true`, `$false`            |                    |
| `EnableLocalContentByLanguageList` | Optional      | Boolean      | IIndicates whether local content by language list should be enabled. The default value is `$null`. You can find the setting in `Settings > Privacy & security > General -> Let Windows provide locally relevant content based on my language list.        | `$true`, `$false` |                    |
| `EnableAppLaunchTracking`          | Optional      | Boolean      | Indicates whether app launch tracking should be enabled. The default value is `$null`. You can find the setting in `Settings > Privacy & security > General -> Let Windows improve Start and search results by tracking app launches.                    | `$true`, `$false`  |                    |
| `ShowContentSuggestion`            | Optional      | Boolean      | Indicates whether content suggestions should be shown. The default value is `$null`. You can find the setting in `Settings > Privacy & security > General -> Show me suggested content in the Settings app.                    | `$true`, `$false`                            |                    |
| `EnableAccountNotifications`       | Optional      | Boolean      | Indicates whether account notifications should be enabled. The default value is `$null`. You can find the setting in `Settings > Privacy & security > General -> Show me notifications in the Settings app.                    | `$true`, `$false`                            |                    |


## EXAMPLES

### EXAMPLE 1 - Set the personalized ads on

```powershell
PS C:\> $params = @{#
	EnablePersonalizedAds = $true
}
PS C:\> Invoke-DscResource -Name Privacy -Method Set -Property $params -ModuleName Microsoft.Windows.Setting.Privacy

# This enables personalized ads for the specified user.
```

### Example 2 - Disable app launch tracking

```powershell
PS C:\> $params = @{
        EnableAppLaunchTracking = $false
    }
PS C:\> Invoke-DscResource -Name Privacy -Method Set -Property $params -ModuleName Microsoft.Windows.Setting.Privacy

# This disables app launch tracking for the specified user.
```

### Example 3 - Turn on content suggestion

```powershell
PS C:\> $params = @{
        ShowContentSuggestion = $true
    }
PS C:\> Invoke-DscResource -Name Privacy -Method Set -Property $params -ModuleName Microsoft.Windows.Setting.Privacy

This enables content suggestions for the specified user.
```
