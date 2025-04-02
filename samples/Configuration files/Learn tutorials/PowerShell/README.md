# Understanding WinGet Configuration Files

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) (_configuration.winget_) that will work with the WinGet command line interface (`winget configure --file [path: configuration.winget]`) or can be run directly by double-clicking on the file.

When run, the `configuration.winget` file will install the following list of applications:

- Microsoft Visual Studio Code

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

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
