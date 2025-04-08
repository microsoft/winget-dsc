<#
    .SYNOPSIS
        The `FindMyDevice` DSC resource is used to manage the Find My Device setting.

    .DESCRIPTION
        This resource is used to enable or disable the Find My Device setting on a Windows device.

    .PARAMETER SID
        The SID of the setting. This is a unique identifier for the setting. The value should be 'IsSingleInstance'.

        NOTE: This property is not configurable and is used internally by the DSC resource. Using the 'IsSingleInstance' value from the base does not work as the class feature is already defined.

    .PARAMETER FindMyDevice
        Specifies whether the Find My Device setting should be enabled or disabled.

    .PARAMETER Reasons
        Returns the reason a property is not in the desired state.
#>
[DscResource()]
class FindMyDevice : SettingsBase
{
    [DscProperty(Key)]
    [ValidateSet('IsSingleInstance')]
    [System.String]
    $SID = 'IsSingleInstance'

    [DscProperty()]
    [SettingStatus] $FindMyDevice

    [DscProperty(NotConfigurable)]
    [WindowsReason[]]
    $Reasons

    FindMyDevice()
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'SID'
            'IsSIngleInstance'
        )

        # Opt in to the optional enums feature
        $this.FeatureOptionalEnums = $true
    }

    [FindMyDevice] Get()
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
