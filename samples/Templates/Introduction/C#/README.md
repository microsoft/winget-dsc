## Understanding WinGet Configuration Files
This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) (*configuration.dsc.yaml*) that will work with the WinGet command line interface (`winget configure --file [path: configuration.dsc.yaml]`) or can be run using [Microsoft Dev Home](https://learn.microsoft.com/windows/dev-home/) Device Configuration.

When run, the `configuration.dsc.yaml` file will install the following list of applications:
* Microsoft Visual Studio Community 2022
    * Required Visual Studio Workloads (ManagedDesktop, Universal)
* GitHub Desktop

The `configuration.dsc.yaml` file will also enable [Developer Mode](https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging) on your device. 

## How to use the WinGet Configuration File
The following two options are available for running a WinGet Configuration file on your device. 

### 1. Windows Package Manager
1. Download the `configuration.dsc.yaml` file to your computer.
1. Open your Windows Start Menu, search and launch "*Windows Terminal*".
1. Type the following: `CD <C:\Users\User\Download>`
1. Type the following: `winget configure --file .\configuration.dsc.yaml`

### 2. Dev Home
1. Download the `configuration.dsc.yaml` file to your computer.
1. Open your Windows Start Menu, search and launch "*Dev Home*".
1. Select the *Machine Configuration* button on the left side navigation.
1. Select the *Configuration file* button
1. Locate and open the WinGet Configuration file downloaded in "step 1".
1. Select the "I agree and want to continue" checkbox.
1. Select the "Set up as admin" button.

## Issues with Configuration file
If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/devhome/issues/new/choose), or [search existing issues](https://github.com/microsoft/devhome/issues) for a pre-existing issue filed by another user.