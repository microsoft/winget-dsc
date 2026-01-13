# Microsoft.WindowsSandbox.DSC

The [Microsoft.Windows.settings](https://www.powershellgallery.com/packages/Microsoft.Windows.Settings) PowerShell module contains the Windows Settings DSC Resource.

> [!IMPORTANT]
> Changing some Windows Settings requires elevation.

## How to use the WinGet Configuration File

The following two options are available for running a WinGet Configuration file on your device.

### 1. File Explorer

1. Download the desired configuration file to your computer:
   - `ChangeWindowsSettings.winget` - Modifies taskbar, color mode, and developer settings
   - `DefaultWindowsSettings.winget` - Sets default Windows settings
   - `DateTimeSettings.winget` - Configures timezone and automatic timezone update settings
   - `PersonalizationSettings.winget` - Configures personalization colors and Start menu folders
   - `USBSettings.winget` - Configures USB notification settings
2. Double-click the downloaded `.winget` file.

### 2. Windows Package Manager

1. Download the desired configuration file to your computer.
2. Open your Windows Start Menu, search and launch "_Windows Terminal_".
3. Type the following: `CD <C:\Users\User\Download>`
4. Type the following: `winget configure --file .\<filename>.winget` (replace `<filename>` with the downloaded file, e.g., `DateTimeSettings`)

## Configuration Files

### ChangeWindowsSettings.winget

Modifies various Windows settings including taskbar alignment, color modes, and developer mode.

### DefaultWindowsSettings.winget

Resets Windows settings to default values (centered taskbar, light mode, developer mode disabled).

### DateTimeSettings.winget

Configures date and time settings including timezone and automatic timezone updates. Requires elevated privileges.

> [!NOTE]
> To see all available timezone IDs, run `Get-TimeZone -ListAvailable` in PowerShell.

### PersonalizationSettings.winget

Configures Windows personalization settings including transparency effects, accent colors, and Start menu folders.

> [!NOTE]
> Valid Start folder names are: Documents, Downloads, Music, Pictures, Videos, Network, UserProfile, Explorer, Settings.

### USBSettings.winget

Configures USB notification settings including notifications for USB errors and weak charger warnings.