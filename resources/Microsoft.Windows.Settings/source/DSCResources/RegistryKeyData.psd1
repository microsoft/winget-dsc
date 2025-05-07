<#
    .SYNOPSIS
        The data for the registry keys to be set by the relevant DSC resource

        This file should only contain data for the registry keys to be set by the DSC resource
#>
@{
    "FindMyDevice" = @{
        PropertyName = 'FindMyDevice'
        Name         = 'LocationSyncEnabled'
        Path         = 'HKLM:\SOFTWARE\Microsoft\MdmCommon\SettingValues\'
        Status       = @{
            Enabled  = 1
            Disabled = 0
            Default  = 0
        }
    }
    "General"      = @(
        @{
            PropertyName = 'EnablePersonalizedAds'
            Name         = 'Enabled'
            Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo\'
            Status       = @{
                Enabled  = 1
                Disabled = 0
                Default  = 0
            }
        },
        @{
            PropertyName = 'EnableLocalContentByLanguageList'
            Name         = 'HttpAcceptLanguageOptOut'
            Path         = 'HKCU:\Control Panel\International\User Profile\'
            Status       = @{
                Enabled  = 0
                Disabled = 1
                Default  = 0
            }
        },
        @{
            PropertyName = 'EnableAppLaunchTracking'
            Name         = 'Start_TrackProgs'
            Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'
            Status       = @{
                Enabled  = 1
                Disabled = 0
                Default  = 1
            }
        }
        @{
            PropertyName = 'ShowContentSuggestion'
            Name         = @('SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled')
            Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\'
            Status       = @{
                Enabled  = 1
                Disabled = 0
                Default  = 1
            }
        }
        @{
            PropertyName = 'EnableAccountNotifications'
            Name         = 'EnableAccountNotifications'
            Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications\'
            Status       = @{
                Enabled  = 1
                Disabled = 0
                Default  = 1
            }
        }
    )
}
