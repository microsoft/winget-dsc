<#
    .SYNOPSIS
        The `FindMyDevice` DSC resource is used to manage the Find My Device setting.

    .DESCRIPTION
        This resource is used to enable or disable the Find My Device setting on a Windows device.

    .PARAMETER IsSingleInstance
        Specifies the resource is a single instance, the value must be 'Yes'.

    .PARAMETER FindMyDevice
        Specifies whether the Find My Device setting should be enabled or disabled.

    .PARAMETER Reasons
        Returns the reason a property is not in the desired state.
#>
[DscResource()]
class FindMyDevice : ResourceBase
{
    [DscProperty(Key)]
    [ValidateSet('Yes')]
    [System.String]
    $IsSingleInstance = 'Yes'

    [DscProperty()]
    [nullable[System.Boolean]]
    $FindMyDevice

    [DscProperty(NotConfigurable)]
    [WindowsReason[]]
    $Reasons

    FindMyDevice() : base ($PSScriptRoot)
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'IsSingleInstance'
        )
    }

    [FindMyDevice] Get()
    {
        # Call the base method to return the properties.
        return ([ResourceBase] $this).Get()
    }

    # Base method Get() call this method to get the current state as a Hashtable.
    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        $state = @{}

        # Get the registry key data
        $keyData = Get-RegistryKeyData -Key 'FindMyDevice'

        # Check if the registry path and key exists including the value
        $settingState = Get-RegistryStatus @keyData

        $state.Add('FindMyDevice', [System.Boolean]$settingState)

        return $state
    }

    [void] Set()
    {
        # Call the base method to enforce the properties.
        ([ResourceBase] $this).Set()
    }

    <#
        Base method Set() call this method with the properties that should be
        enforced and that are not in desired state.
    #>
    hidden [void] Modify([System.Collections.Hashtable] $properties)
    {
        if ($null -ne $this.FindMyDevice)
        {
            $this.SetFindMyDevice($properties.FindMyDevice)
        }
    }

    [System.Boolean] Test()
    {
        # Call the base method to test all of the properties that should be enforced.
        return ([ResourceBase] $this).Test()
    }

    hidden [void] SetFindMyDevice()
    {
        $keyData = Get-RegistryKeyData -Key 'FindMyDevice' -OnlyKeyPath

        # Add the value to the key data
        $keyData.Add('Value', [System.Int32]$this.Value)

        # Set the registry with the new value
        Set-RegistryStatus @keyData
    }
}
