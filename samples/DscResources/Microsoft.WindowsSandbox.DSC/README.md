# Microsoft.WindowsSandbox.DSC
The [Microsoft.WindowsSandbox.DSC](https://www.powershellgallery.com/packages/Microsoft.WindowsSandbox.DSC) PowerShell module contains the WindowsSandbox DSC Resource. This resource accepts either a reference to a Windows Sandbox .WSB file or properties to configure and launch an instance of the Windows Sandbox.

>Note: The Windows Sandbox is an ephemoral instance of Windows. It also defaults to an administrative context when running the LogonCommand.

Prior to running this configuration, users should be on either Windows PRO or Windows enterprise. The "Windows Sandbox" optional feature also needs to be enabled.

The "full.sandbox.dsc.yaml" configuration is not fully capable of verifying the Windows SKU or enabling Windows optional features via the WinGet CLI (and subsequently Dev Home). The Windows optional features can be enabled in a configuration when run via the Microsoft.WinGet.Configuration.

The "full.sandbox.dsc.yaml" configuration can be run via the Microsoft.WinGet.Configuration module.

Install the module using:
```PowerShell
Install-Module -Name Microsoft.WindowsSandbox.DSC -AllowPrerelease
```

Run the configuration in PowerShell 7 using:
```PowerShell
get-WinGetConfiguration -File full.sandbox.dsc.yaml | Invoke-WinGetConfiguration
```

## How to use the WinGet Configuration File
The following two options are available for running a WinGet Configuration file on your device. 

### 1. Windows Package Manager
1. Download the `sandbox.dsc.yaml` file to your computer.
1. Open your Windows Start Menu, search and launch "*Windows Terminal*".
1. Type the following: `CD <C:\Users\User\Download>`
1. Type the following: `winget configure --file .\sandbox.dsc.yaml`

### 2. Dev Home
1. Download the `sandbox.dsc.yaml` file to your computer.
1. Open your Windows Start Menu, search and launch "*Dev Home*".
1. Select the *Machine Configuration* button on the left side navigation.
1. Select the *Configuration file* button
1. Locate and open the WinGet Configuration file downloaded in "step 1".
1. Select the "I agree and want to continue" checkbox.
1. Select the "Set up as admin" button.
