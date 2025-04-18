# DSC Samples

## Using the sample configurations

Download the \*.winget files to your local system. They can be executed by double-clicking on the file from file explorer. They can also be executed by running `winget configure <path to configuration file>`.

Some DSC resources may need to run with administrator privileges.
The `securityContext: elevated` field under the `directives` section of a resource indicates this requirement.
When set to `elevated`, WinGet will prompt for **one** UAC approval at the start of the configuration. WinGet will then launch two processes: one that runs resources with elevated privileges and another that runs resources with the current user's privileges.

If the configuration is leveraging the [WinGet DSC resource](https://www.powershellgallery.com/packages/Microsoft.WinGet.DSC) to install packages, there are also limitations in some cases specific to the installers that may either require or prohibit installation in administrative context.

### GitHub projects (Repositories)

Sample configurations have been provided for various GitHub repositories. These configurations ideally should be placed in a `.config` folder in the root of the project directory. Some DSC resources may have parameters that allow you to pass in a relative file path. The reserved variable `$(WinGetConfigRoot)` can be used to specify the full path of the configuration file. An example of how to use that variable with a relative file path is shown below:

```yaml
- resource: Microsoft.VisualStudio.DSC/VSComponents
  dependsOn:
  directives:
    description: Install required VS workloads from .vsconfig file
    allowPrerelease: true
    securityContext: elevated
  settings:
    productId: Microsoft.VisualStudio.Product.Community
    channelId: VisualStudio.17.Release
    vsConfigFile: '${WinGetConfigRoot}\..\.vsconfig'
```

### Learn to Code (Templates)

Sample configurations in this directory are directly related to the [Windows development paths](https://learn.microsoft.com/windows/dev-environment/#development-paths). These configurations will allow you to automatically set up your device and begin developing in your preferred language quickly.

### Sample DSC Resources (DscResources)

Examples for a few specific DSC Resources are under the [DscResources](./DscResources/) directory.

### Create your own

Writing YAML is a pain. To help you get started creating your own, there is a [sample tool](https://github.com/microsoft/winget-create/blob/main/Tools/WingetCreateMakeDSC.ps1) for authoring in the winget-create repo. It currently only supports adding apps, but give it a try and contribute to make it better!
