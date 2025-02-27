# Understanding WinGet Configuration Files

This folder contains a WinGet Configuration File (_configuration.winget_) that will work with the Windows Package Manager command line interface (`winget configure --file [path: configuration.winget]`) or can be run using Microsoft Dev Home Device Configuration.

When run, the `configuration.winget` file will install the following list of applications:

- Microsoft Visual Studio Community 2022
    - Required Visual Studio Workloads (NodeJS, Universal)
- GitHub Desktop

The `configuration.winget` file will also enable [Developer Mode](https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging) on your device.

## How to use the WinGet Configuration File

### Windows Package Manager

1. Download the `configuration.winget` file to your computer.
1. Open your Windows Start Menu, search and launch "_Windows Terminal_".
1. Type the following: `CD [C:\Users\User\Download]`
1. Type the following: `winget configure --file .\configuration.winget`

### Dev Home

1. Download the `configuration.winget` file to your computer.
1. Open your Windows Start Menu, search and launch "_Dev Home_".
1. Select the _Machine Configuration_ button on the left side navigation.
1. Select the _Configuration file_ button
1. Locate and open the WinGet Configuration file downloaded in "step 1".
1. Select the "I agree and want to continue" checkbox.
1. Select the "Set up as admin" button.
