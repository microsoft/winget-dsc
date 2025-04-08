<#
    .SYNOPSIS
        The localized resource strings in English (en-US) for the
        resource Microsoft.Windows.Settings module. This file should only contain
        localized strings for private and public functions.
#>

ConvertFrom-StringData @'
    ## Get-RegistryStatus
    GetRegistryStatusRegistryManualManipulation_ErrorMessage = "The registry path '{0}' is not in the expected state. Entries have been manually modified. Cannot determine the current state."
    GetRegistryStatus_SearchMessage = "Searching '{0}' key in '{1}'."
    GetRegistryStatus_FoundMessage = "Found '{0}' key in '{1}'."
    GetRegistryStatus_DefaultMessage = "Returning default value '{0}' for '{1}'."

    ## Get-RegistryKeyData
    GetRegistryKeyData_SearchMessage = Searching '{0}' key in '{1}'.
'@
