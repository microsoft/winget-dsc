<#
    .SYNOPSIS
        The localized resource strings in English (en-US) for the
        resource FindMyDevice class. This file should only contain
        localized strings for private functions, public command, and
        classes (that are not a DSC resource).
#>

ConvertFrom-StringData @'
    ## Strings overrides for the ResourceBase's default strings.
    # None

    ## Strings directly used by the derived class FindMyDevice.
    FindMyDeviceRegistryKey = Searching '{0}' key in '{1}' (0001).
'@
