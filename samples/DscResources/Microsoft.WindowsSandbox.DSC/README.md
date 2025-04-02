# Microsoft.WindowsSandbox.DSC

The [Microsoft.WindowsSandbox.DSC](https://www.powershellgallery.com/packages/Microsoft.WindowsSandbox.DSC) PowerShell module contains the WindowsSandbox DSC Resource. This resource accepts either a reference to a Windows Sandbox .WSB file or properties to configure and launch an instance of the Windows Sandbox.

> Note: The Windows Sandbox is an ephemoral instance of Windows. It also defaults to an administrative context when running the LogonCommand.

Prior to running this configuration, users should be on either Windows PRO or Windows enterprise. The "Windows Sandbox" optional feature also needs to be enabled.

The "full.sandbox.winget" configuration is not fully capable of verifying the Windows SKU or enabling Windows optional features via the WinGet CLI. The Windows optional features can be enabled in a configuration when run via the Microsoft.WinGet.Configuration.

The "full.sandbox.winget" configuration can be run via the Microsoft.WinGet.Configuration module.

Install the module using:

```PowerShell
Install-Module -Name Microsoft.WindowsSandbox.DSC -AllowPrerelease
```

Run the configuration in PowerShell 7 using:

```PowerShell
get-WinGetConfiguration -File full.sandbox.winget | Invoke-WinGetConfiguration
```

## How to use the WinGet Configuration File

The following two options are available for running a WinGet Configuration file on your device.

### 1. File Explorer

1. Download the `sandbox.winget` file to your computer.
2. Double-click the `sandbox.winget` file.

### 2. Windows Package Manager

1. Download the `sandbox.winget` file to your computer.
2. Open your Windows Start Menu, search and launch "_Windows Terminal_".
3. Type the following: `CD <C:\Users\User\Download>`
4. Type the following: `winget configure --file .\sandbox.winget`
