# Microsoft.Windows.Settings

The DSC resource module `Microsoft.Windows.Settings` provides a set of Desired State Configuration (DSC) resources for managing Windows settings. These resources allow you to configure and manage settings such as app preferences, device experiences, and USB configurations through PowerShell DSC.

## Wiki and module under construction :construction:

## Resources :construction:

- **AdvancedAppSettings**: Manage advanced application settings including app source preferences and device sharing experiences.
- **USB**: Manage USB device settings including enabling/disabling devices, allowing wake, and selective suspend options.

## Usage :construction:

To use these resources, import the module and invoke the desired DSC resource with the appropriate parameters.

```powershell
Import-Module -Name Microsoft.Windows.Settings

Invoke-DscResource -ModuleName Microsoft.Windows.Settings -Name AdvancedAppSettings -Method Set -Property @{
    SID = 'S-1-5-21-1234567890-123456789-1234567890-1001';
    AppSourcePreference = 'PreferStore';
    ShareDeviceExperience = 'Everyone';
    ArchiveApp = $true;
}
```

For more detailed examples and parameter descriptions, refer to the individual resource documentation.
