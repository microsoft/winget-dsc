# Sample configurations for specific DSC resources

The sample configurations provided in this directory showcase how to create configuration documents both for DSC and WinGet. It's up to you to decide which tool you want. To use DSC, follow the prerequisites. WinGet is included in:

- Windows 10 Version 1809 and later
- Windows 11

Earlier versions of Windows 10 can use the Microsoft Store to download the App Installer package.

## Prerequisites

- [Desired State Configuration - v3.0.0-preview.10+](https://github.com/PowerShell/DSC/tags)
- [PSDesiredStateConfiguration - v2.0.7](https://www.powershellgallery.com/packages/PSDesiredStateConfiguration/2.0.7)

## Getting started

To test out each sample configuration, you only need a PowerShell terminal session. In the sample name, you should find the relevant tool belonging to which tool. To illustrate, see the following example:

```powershell
# Use WinGet 
winget configure --file InstallVSCodeInsiders.winget.document.yaml # Use --accept-configuration-agreements to ignore prompt messages

# Use `dsc.exe`
dsc config set --path InstallVSCodeInsiders.winget.document.yaml

# Use PSDesiredStateConfiguration
Start-DscConfiguration -Path InstallVSCodeInsider.ps1 -Force
```

If you don't want to use a _configuration document_, you can always invoke it using `Invoke-DscResource` command. If you inspect the module file, move examples will be found how to use it with the `Invoke-DscResource` command.

## Resources

### GitDsc

### Microsoft.DotNet.Dsc

### Microsoft.VSCode.Dsc

Supports multiple resources to install and work with Visual Studio Code. The following resources can be used:

- **VSCodeExtension:** DSC resource allowing you to install, update, and remove Visual Studio Code extensions. This resource ensures that the specified Visual Studio Code extension is in the desired state.
- **VSCodeInstaller:** DSC resource allowing you to install, update, and remove Visual Studio Code. This resource ensures that the specified version of Visual Studio Code is in the desired state.

## Microsoft.Windows.Developer

### Microsoft.Windows.Setting.Accessibility

### Microsoft.WindowsSandbox.DSC

### NpmDsc

### PythonPip3Dsc

### YarnDsc