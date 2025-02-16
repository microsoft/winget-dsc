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
class SettingsBase : ResourceBase
{
    [DscProperty(Key)]
    [ValidateSet('Yes')]
    [System.String]
    $IsSingleInstance = 'Yes'

    hidden [System.String] $ClassName

    SettingsBase() : base ($PSScriptRoot)
    {
        # These properties will not be enforced.
        $this.ExcludeDscProperties = @(
            'IsSingleInstance'
        )

        $this.ClassName = $this.GetType().Name
    }

    [SettingsBase] Get()
    {
        # Call the base method to return the properties.
        return ([ResourceBase] $this).Get()
    }

    # Base method Get() call this method to get the current state as a Hashtable.
    [System.Collections.Hashtable] GetCurrentState([System.Collections.Hashtable] $properties)
    {
        # Use the Get-DscProperty cmdlet to get the properties to search instead of properties from GetCurrentState
        $propsToSearch = Get-DscProperty -InputObject $this `
            -Attribute Optional `
            -ExcludeName 'IsSingleInstance'

        # Initialize the state
        $state = @{}

        # Get the registry key data
        $keyData = Get-RegistryKeyData -Key $this.ClassName

        $propsToSearch.Keys | ForEach-Object {
            # Get the property name
            $property = $_

            # Get the key data for the property
            $key = $keyData | Where-Object { $_.PropertyName -eq $property }

            # Remove the PropertyName key from the key data
            $key.Remove('PropertyName')

            # Get the status of the property
            $settingState = Get-RegistryStatus @key

            # Add the property and status to the state
            $state.Add($_, [SettingStatus]$settingState)
        }

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
        $properties.GetEnumerator() | ForEach-Object {
            # Capture the property name to filter on
            $propertyName = $_.Key -as [System.String]

            # The value as string else it can be empty
            $propertyValue = $_.Value -as [System.String]

            # Search the entry in the registry key data
            $entry = Get-RegistryKeyData -Key $this.ClassName | Where-Object { $_.PropertyName -eq $propertyName }

            # Build the parameters for Set-RegistryStatus
            $params = @{
                Name = $entry.Name
                Path = $entry.Path
                Value = $entry.Status[$propertyValue]
            }

            # Add the Type parameter if it exists
            if ($entry.Type)
            {
                $params.Add('Type', $entry.Type)
            }

            Set-RegistryStatus @params
        }
    }

    [System.Boolean] Test()
    {
        # Call the base method to test all of the properties that should be enforced.
        return ([ResourceBase] $this).Test()
    }
}
