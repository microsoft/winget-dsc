<#
    .SYNOPSIS
        The possible states for the DSC resource parameter SettingStatus.
        This enum is used to specify the desired state of settings that can be enabled or disabled e.g. have a value of 0 or 1.

        To opt-in for enums through the DscResource.Base class, set the property FeatureOptionalEnums to $true in the constructor of the DSC resource class.
#>
enum SettingStatus
{
    Enabled = 1
    Disabled
}
