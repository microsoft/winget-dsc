# DscResources

## Sample Configurations for Specific DSC Resources

The sample configurations provided in this directory showcase how to create WinGet configuration files utilizing PowerShell DSC resources for specific scenarios. Each sample is available in two versions:

- **v2** (`*.winget`) — Uses the DSC v2 schema (`configuration-dsc-schema/0.2`) processed by the default WinGet DSC processor.
- **v3** (`*.v3.winget`) — Uses the dscv3 processor syntax with explicit module installs and the updated document structure.

> [!NOTE]
> The v3 configurations require the `dscv3` processor, available in WinGet v1.29+ with DSC v3 installed. Adapted resources in v3 require explicit module installation via `Microsoft.DSC.Transitional/RunCommandOnSet`.

### [GitDsc](https://www.powershellgallery.com/packages/GitDsc/0.1.2-alpha)

Supports cloning a new repository and adding/removing remote connections to other repositories.

| Sample | v2 | v3 |
|--------|----|----|
| Clone WinGet Repository | `CloneWingetRepository.winget` | `CloneWingetRepository.v3.winget` |

### [Microsoft.VSCode.Dsc](https://www.powershellgallery.com/packages/Microsoft.VSCode.Dsc/0.1.5-alpha)

Manage Visual Studio Code extension installation and removal through DSC.

| Sample | v2 | v3 |
|--------|----|----|
| Install Extensions | `InstallVSCodeExtensions.winget` | `InstallVSCodeExtensions.v3.winget` |
| Advanced Extension Management | `AdvancedExtensionManagement.winget` | `AdvancedExtensionManagement.v3.winget` |
| Remove Extensions | `RemoveExtensions.winget` | `RemoveExtensions.v3.winget` |
| Complete Dev Environment | `CompleteDevEnvironment.winget` | `CompleteDevEnvironment.v3.winget` |
| Insiders & Local Extensions | `InsidersAndLocalExtensions.winget` | `InsidersAndLocalExtensions.v3.winget` |

### [Microsoft.Windows.Developer](https://www.powershellgallery.com/packages/Microsoft.Windows.Developer/0.1.3-alpha)

Modify various Windows Settings such as showing seconds in clock, hiding file extensions, or showing the task view button.

| Sample | v2 | v3 |
|--------|----|----|
| Modify Windows Settings | `ModifyWindowsSettings.winget` | `ModifyWindowsSettings.v3.winget` |
| Revert Windows Settings | `RevertWindowsSettings.winget` | `RevertWindowsSettings.v3.winget` |

### [Microsoft.Windows.Settings](https://www.powershellgallery.com/packages/Microsoft.Windows.Settings/0.1.0-alpha)

Modify various Windows Settings such as App Color Theme, Windows Color Theme, Taskbar Alignment, and Developer Mode.

| Sample | v2 | v3 |
|--------|----|----|
| Change Windows Settings | `ChangeWindowsSettings.winget` | `ChangeWindowsSettings.v3.winget` |
| Default Windows Settings | `DefaultWindowsSettings.winget` | `DefaultWindowsSettings.v3.winget` |
| Date/Time Settings | `DateTimeSettings.winget` | `DateTimeSettings.v3.winget` |
| Personalization Settings | `PersonalizationSettings.winget` | `PersonalizationSettings.v3.winget` |
| USB Settings | `USBSettings.winget` | `USBSettings.v3.winget` |

### [Microsoft.WindowsSandbox.DSC](https://www.powershellgallery.com/packages/Microsoft.WindowsSandbox.DSC/0.1.1-alpha)

Create a new instance of Windows Sandbox by either providing a custom .wsb file or specifying parameters.

> [!NOTE]
> [Windows Sandbox](https://learn.microsoft.com/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview#prerequisites) requires Windows 10 Pro or Enterprise, build version 18305 or Windows 11.

| Sample | v2 | v3 |
|--------|----|----|
| Basic Sandbox | `sandbox.winget` | `sandbox.v3.winget` |
| Full Sandbox with WinGet | `full.sandbox.winget` | `full.sandbox.v3.winget` |

### [PowerToysConfigure](https://www.powershellgallery.com/packages/PowerToysConfigure)

Install and configure Microsoft PowerToys settings through DSC.

| Sample | v2 | v3 |
|--------|----|----|
| PowerToys Configuration | `PowerToys.winget` | `PowerToys.v3.winget` |

### [RustDsc](https://github.com/microsoft/winget-dsc/tree/main/resources/RustDsc)

Install Rust command-line tools globally using Cargo.

| Sample | v2 | v3 |
|--------|----|----|
| Cargo Tool Install | `cargo-install.winget` | `cargo-install.v3.winget` |
