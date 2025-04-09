<#
    .SYNOPSIS
        The `FindMyDevice` DSC resource is used to manage the Find My Device setting.

    .DESCRIPTION
        This resource is used to enable or disable the Find My Device setting on a Windows device.

    .PARAMETER IsSingleInstance
        Specifies the resource is a single instance, the value must be 'Yes'

    .PARAMETER FindMyDevice
        Specifies whether the Find My Device setting should be enabled or disabled.

    .PARAMETER Reasons
        Returns the reason a property is not in the desired state.
#>
[DscResource()]
class FindMyDevice : SettingsBase
{
    [DscProperty(Key)]
    [ValidateSet('Yes')]
    [System.String]
    $IsSingleInstance = 'Yes'

    [DscProperty()]
    [SettingStatus] $FindMyDevice

    [DscProperty(NotConfigurable)]
    [WindowsReason[]]
    $Reasons

    FindMyDevice()
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'IsSingleInstance'
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
