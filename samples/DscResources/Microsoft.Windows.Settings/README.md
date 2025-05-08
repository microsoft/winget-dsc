# Microsoft.WindowsSandbox.DSC

The [Microsoft.Windows.settings](https://www.powershellgallery.com/packages/Microsoft.Windows.Settings) PowerShell module contains the Windows Settings DSC Resource.

> [!NOTE]
> Changing some Windows Settings requires elevation.

## How to use the WinGet Configuration File

The following two options are available for running a WinGet Configuration file on your device.

### 1. File Explorer

1. Download the `ChangeWindowsSettings.winget` and/or `DefaultWindowsSettings.winget` file to your computer.
2. Double-click the `ChangeWindowsSettings.winget` or the `DefaultWindowsSettings.winget` file (depending on which one you downloaded).

### 2. Windows Package Manager

1. Download the `ChangeWindowsSettings.winget` and/or `DefaultWindowsSettings.winget` file to your computer.
2. Open your Windows Start Menu, search and launch "_Windows Terminal_".
3. Type the following: `CD <C:\Users\User\Download>`
4. Type the following: `winget configure --file .\ChangeWindowsSettings.winget`
