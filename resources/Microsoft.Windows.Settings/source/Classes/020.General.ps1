
<#
    .SYNOPSIS
        The `General` DSC resource is used to manage the General settings under Privacy & security.

    .DESCRIPTION
        This resource is used to enable or disable the General settings under Privacy & security on a Windows device.

    .PARAMETER SID
        The SID of the setting. This is a unique identifier for the setting. The value should be 'IsSingleInstance'.

        NOTE: This property is not configurable and is used internally by the DSC resource. Using the 'IsSingleInstance' value from the base does not work as the class feature is already defined.

    .PARAMETER FindMyDevice
        Specifies whether the Find My Device setting should be enabled or disabled.

    .PARAMETER EnablePersonalizedAds
        Specifies whether personalized ads should be enabled or disabled.

    .PARAMETER EnableLocalContentByLanguageList
        Specifies whether local content by language list should be enabled or disabled.

    .PARAMETER EnableAppLaunchTracking
        Specifies whether app launch tracking should be enabled or disabled.

    .PARAMETER ShowContentSuggestion
        Specifies whether content suggestions should be shown or not.

    .PARAMETER EnableAccountNotifications
        Specifies whether account notifications should be enabled or disabled.

    .PARAMETER Reasons
        Returns the reason a property is not in the desired state.
#>
[DSCResource()]
class General : SettingsBase
{
    [DscProperty(Key)]
    [ValidateSet('Yes')]
    [System.String]
    $SID = 'Yes'

    [DscProperty()]
    [SettingStatus] $EnablePersonalizedAds

    [DscProperty()]
    [SettingStatus] $EnableLocalContentByLanguageList

    [DscProperty()]
    [SettingStatus] $EnableAppLaunchTracking

    [DscProperty()]
    [SettingStatus] $ShowContentSuggestion

    [DscProperty()]
    [SettingStatus] $EnableAccountNotifications

    [DscProperty(NotConfigurable)]
    [WindowsReason[]]
    $Reasons

    General()
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'IsSingleInstance',
            'SID'
        )

        # Opt in to the optional enums feature
        $this.FeatureOptionalEnums = $true
    }

    [General] Get()
    {
        # Call the base method to return the properties.
        return ([SettingsBase] $this).Get()
    }

    [void] Set()
    {
        # Call the base method to enforce the properties.
        ([SettingsBase] $this).Set()
    }

    [System.Boolean] Test()
    {
        # Call the base method to test all of the properties that should be enforced.
        return ([SettingsBase] $this).Test()
    }
}
