# DSC Resources

This folder contains the initial prototypes for various DSC resources that could be utilized in a configuration yaml.

## Requirements

Before you get started, install the [PSDesiredStateConfiguration v2.0.7](https://www.powershellgallery.com/packages/PSDesiredStateConfiguration/2.0.7) PowerShell package:

```powerShell
Install-Module -Name PSDesiredStateConfiguration -RequiredVersion 2.0.7
```

> To verify that the package is installed, run `Get-InstalledModule` and check that the version is exactly 2.0.7.

## Executing a DSC Resource

PowerShell recursively searches for the module in any of the paths specified in `$env:PSModulePath`. This means you can either copy the DSC Resource module into one of those paths or you can [modify the environment variable](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath?view=powershell-7.3#modifying-psmodulepath) to point to the location of your module.

Once the above step is complete, you should be able to see your loaded DSC resource by running `Get-DSCResource`.

You should now be able to execute the loaded DSC resource by running `Invoke-DSCResource`. Here is a usage example for the Visual Studio DSC Resource to use as a reference for structuring your command:

```powershell
# Define the properties in a hashtable from Get-DscResource
$properties = @{
    HttpsUrl      = 'https://github.com/microsoft/winget-dsc.git'
    RootDirectory = 'C:\Source'
    Ensure        = 'Present'
}

# Define the parameters for Invoke-DscResource
$params = @{
    Name       = 'GitClone'
    Method     = 'Set'
    ModuleName = 'GitDsc'
    Property   = $properties
}

# Invoke the DSC resource
Invoke-DscResource @params
```

## Troubleshooting

If you don't see your DSC Resource loaded, try the following:

1. Try importing the module using `Import-Module`. If the module cannot be imported, then it cannot load the DSC resource.

    ```powershell
    Import-Module <path to DSC module .psd1 file>
    ```

2. Restarting your shell.
3. Verifying that your syntax in the module is correct. No warning is shown to the user if your PowerShell module file is invalid.
4. Verifying the `$env:PSModulePath` contains the folder path where your module is located.
