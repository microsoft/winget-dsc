---
external help file: Microsoft.Windows.Setting.Update.psm1-Help.xml
Module Name: Microsoft.Windows.Setting.Update
ms.date: 11/04/2024
online version:
schema: 2.0.0
title: WindowsUpdate
---

# WindowsUpdate

## SYNOPSIS

The `WindowsUpdate` DSC resource allows you to configure various Windows Update settings, including enabling or disabling specific update services, setting download and upload rates, and configuring active hours for updates.

## DESCRIPTION

The `WindowsUpdate` DSC resource allows you to configure various Windows Update settings, including enabling or disabling specific update services, setting download and upload rates, and configuring active hours for updates.

## PARAMETERS

| **Parameter**                                      | **Attribute** | **DataType** | **Description**                                                                  | **Allowed Values**                              |
| -------------------------------------------------- | ------------- | ------------ | -------------------------------------------------------------------------------- | ----------------------------------------------- |
| `SID`                                              | Key           | String       | The security identifier. This is a key property and should not be set manually.  | N/A                                             |
| `IsContinuousInnovationOptedIn`                    | Optional      | Boolean      | Indicates whether the device is opted in to continuous innovation updates.       | `$true`, `$false`                               |
| `AllowMUUpdateService`                             | Optional      | Boolean      | Allows updates from Microsoft Update service.                                    | `$true`, `$false`                               |
| `IsExpedited`                                      | Optional      | Boolean      | Indicates whether updates should be expedited.                                   | `$true`, `$false`                               |
| `AllowAutoWindowsUpdateDownloadOverMeteredNetwork` | Optional      | Boolean      | Allows automatic Windows Update downloads over metered networks.                 | `$true`, `$false`                               |
| `RestartNotificationsAllowed`                      | Optional      | Boolean      | Allows restart notifications for updates.                                        | `$true`, `$false`                               |
| `SmartActiveHoursState`                            | Optional      | String       | Configures smart active hours state for updates.                                 | `Enabled`, `Disabled`                           |
| `UserChoiceActiveHoursEnd`                         | Optional      | Integer      | Specifies the end time for user-chosen active hours in `HH:MM` format.           | Any valid time in `HH:MM` format                |
| `UserChoiceActiveHoursStart`                       | Optional      | Integer      | Specifies the start time for user-chosen active hours in `HH:MM` format.         | Any valid time in `HH:MM` format                |
| `DownloadMode`                                     | Optional      | Integer      | Specifies the download mode for updates.                                         | `Foreground`, `Background`, `Bypass`, `None`    |
| `DownloadRateBackgroundBps`                        | Optional      | Integer      | Specifies the background download rate for updates in Bps.                       | Any positive integer value. E.g. 20000 is 2MBPs |
| `DownloadRateForegroundBps`                        | Optional      | Integer      | Specifies the foreground download rate for updates in Bps.                       | Any positive integer value                      |
| `DownloadRateBackgroundPct`                        | Optional      | Integer      | Specifies the background download rate for updates as a percentage of bandwidth. | 0-100                                           |
| `DownloadRateForegroundPct`                        | Optional      | Integer      | Specifies the foreground download rate for updates as a percentage of bandwidth. | 0-100                                           |
| `UploadLimitGBMonth`                               | Optional      | Integer      | Specifies the upload limit for updates in GB per month.                          | 5-500                                           |
| `UpRatePctBandwidth`                               | Optional      | Integer      | Specifies the upload rate as a percentage of bandwidth.                          | 0-100                                           |

## EXAMPLES

### EXAMPLE 1

```powershell
$params = @{}
Invoke-DscResource -Name WindowsUpdate -Method Set -Property $params -ModuleName Microsoft.Windows.Setting.WindowsUpdate

# This command gets the current Windows Update settings.
```
