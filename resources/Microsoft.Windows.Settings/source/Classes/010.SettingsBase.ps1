<#
    .SYNOPSIS
        The `SettingsBase` class is the base class for all settings resources.

    .DESCRIPTION
        This class is the base class for all settings resources. It provides the basic functionality
        for getting, setting, and testing the properties of the settings resources.

    .PARAMETER IsSingleInstance
        Specifies the resource is a single instance, the value must be 'Yes'.
#>
class SettingsBase : ResourceBase
{
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
            -ExcludeName @('SID', 'IsSingleInstance')

        # Initialize the state
        $state = @{}

        # Get the registry key data
        $keyData = Get-RegistryKeyData -Key $this.ClassName

        $propsToSearch.Keys | ForEach-Object {
            # Get the property name
            $property = $_

            # Get the key data for the property
            $key = $keyData | Where-Object -Property PropertyName -EQ $property
            
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
                Name  = $entry.Name
                Path  = $entry.Path
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
