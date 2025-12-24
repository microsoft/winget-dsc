# DSC Samples

## Understanding WinGet Configuration Files

WinGet configuration files are YAML based configuration files that allow you to setup your machine in a desired state. These configurations are idempotent meaning that they can be executed multiple times safely to produce the same result. The configuration will only apply a change if the current state does not match the desired state.

## Using the sample configurations

Download the `*.winget` files to your local system. They can be executed by double-clicking on the file from file explorer. They can also be executed by running `winget configure <path to configuration file>`.

Some DSC resources may need to run with administrator privileges.
The `securityContext: elevated` field under the `directives` section of a resource indicates this requirement.
When set to `elevated`, WinGet will prompt for **one** UAC approval at the start of the configuration. WinGet will then launch two processes: one that runs resources with elevated privileges and another that runs resources with the current user's privileges.

If the configuration is leveraging the [WinGet DSC resource](https://www.powershellgallery.com/packages/Microsoft.WinGet.DSC) to install packages, there are also limitations in some cases specific to the installers that may either require or prohibit installation in administrative context.

### GitHub projects (Repositories)

Samples for popular repositories are included in the [Repositories](./Repositories/) directory. They are organized as `<Organization>\<Repository Name>\configuration.winget`. These samples are designed to help you quickly set up a development environment for building popular open-source projects. The configurations are tailored to the specific requirements of each project, ensuring that you have all the necessary tools and dependencies installed needed for the development process.

Repositories that make use of a WinGet configuration file are documented in [GitHubProjects.md](./GitHubProjects.md).

### Microsoft Learn Tutorials (Templates)

Sample configurations in the [Learn Tutorials](./Configuration%20files/Learn%20tutorials/) directory are directly related to the [Windows development paths](https://learn.microsoft.com/windows/dev-environment/#development-paths). These configurations will allow you to automatically set up your device and begin developing in your preferred language quickly.

### Sample DSC Resources (DscResources)

Examples for a few specific DSC Resources are under the [DscResources](./DscResources/) directory.

### Virtual Machines

The VirtualMachines folder contains a script that will create two Virtual Machines. A Dev Tools Image VM, and a MSIX Packaging Toolkit VM. For more information see the [Virtual Machines README.md](./virtualmachines/readme.md)

### Create your own

Writing YAML is a pain. To help you get started creating your own, there is a [sample tool](https://github.com/microsoft/winget-create/blob/main/Tools/WingetCreateMakeDSC.ps1) for authoring in the winget-create repo. It currently only supports adding apps, but give it a try and contribute to make it better!
