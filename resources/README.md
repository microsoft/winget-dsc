## DSC Resources

This folder contains the initial prototypes for various DSC resources that could be utilized in a configuration yaml. 

### Requirements
Before you get started, install the [PSDesiredStateConfiguration v2.0.6](https://www.powershellgallery.com/packages/PSDesiredStateConfiguration/2.0.6) PowerShell package:

```PowerShell
    Install-Module -Name PSDesiredStateConfiguration -RequiredVersion 2.0.6
```

> To verify that the package is installed, run `Get-InstalledModule` and check that the version is exactly 2.0.6.


### Executing a DSC Resource

PowerShell recursively searches for the module in any of the paths specified in `$env:PSModulePath`. This means you can either copy the DSC Resource module into one of those paths or you can [modify the environment variable](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath?view=powershell-7.3#modifying-psmodulepath) to point to the location of your module.

Once the above step is complete, you should be able to see your loaded DSC resource by running `Get-DSCResource`. 

You should now be able to execute the loaded DSC resource by running `Invoke-DSCResource`. Here is a usage example for the Visual Studio DSC Resource to use as a reference for structuring your command: 

```PowerShell
Invoke-DscResource -Name VisualStudioComponents -Method Get -ModuleName Microsoft.VisualStudio.DSC -Property @{ productId = 'Microsoft.VisualStudio.Product.Enterprise'; channelId = 'VisualStudio.17.Release'; components=@("Microsoft.VisualStudio.Component.Windows10SDK.20348")}
```

### Troubleshooting:
If you don't see your DSC Resource loaded, try the following:
1. Restarting your shell.
2. Verifying that your syntax in the module is correct. No warning is shown to the user if your PowerShell module file is invalid.
3. Verifying the `$env:PSModulePath` contains the folder path where your module is located.

