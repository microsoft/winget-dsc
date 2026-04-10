# Microsoft.VSCode.Dsc Sample Configurations

This directory contains sample WinGet configuration files that demonstrate how to use the `Microsoft.VSCode.Dsc` module to manage Visual Studio Code extensions through DSC (Desired State Configuration).

## Available Samples

### 1. InstallVSCodeExtensions.winget

A basic configuration that installs Visual Studio Code and several common extensions including:

- Python extension (`ms-python.python`)
- C# extension (`ms-dotnettools.csharp`)
- TypeScript extension (`ms-vscode.vscode-typescript-next`)
- GitLens (`eamodio.gitlens`)
- Prettier (`esbenp.prettier-vscode`)
- Live Server (`ritwickdey.liveserver`)

### 2. AdvancedExtensionManagement.winget

Demonstrates advanced extension management features:

- Installing specific extension versions
- Installing pre-release extensions using the `PreRelease` parameter
- Managing extensions for VS Code Insiders using the `Insiders` parameter

### 3. RemoveExtensions.winget

Shows how to remove Visual Studio Code extensions by setting `Exist: false`.

### 4. CompleteDevEnvironment.winget

A comprehensive development environment setup that includes:

- Visual Studio Code installation
- Essential development tools (Git, Node.js, Python)
- Extensions organized by development area:
    - General development (GitLens, Git Graph, Prettier)
    - Python development (Python, Pylance, Debugger)
    - JavaScript/TypeScript development (ESLint, npm IntelliSense)
    - Web development (HTML CSS Support, Live Server, Auto Rename Tag)
    - .NET development (C#, .NET Runtime)
    - PowerShell development
    - Docker and containerization
    - Themes and appearance

### 5. InsidersAndLocalExtensions.winget

Demonstrates advanced scenarios:

- Installing VS Code Insiders
- Installing extensions from local VSIX files
- Managing extensions specifically for VS Code Insiders
- Installing pre-release extensions for Insiders

## VSCodeExtension DSC Resource Parameters

The `VSCodeExtension` resource supports the following parameters:

| Parameter    | Type    | Description                                             | Default |
| ------------ | ------- | ------------------------------------------------------- | ------- |
| `Name`       | String  | The name of the Visual Studio Code extension (required) | -       |
| `Version`    | String  | Specific version to install (optional)                  | Latest  |
| `Exist`      | Boolean | Whether the extension should exist                      | `true`  |
| `PreRelease` | Boolean | Install pre-release version                             | `false` |
| `Insiders`   | Boolean | Manage extension for VS Code Insiders                   | `false` |

## Usage Instructions

1. **Prerequisites**: Ensure you have WinGet and DSC v2 installed on your system.

2. **Running a Configuration**: Use the following command to apply a configuration:

   ```powershell
   winget configure --file path\to\configuration.winget
   ```

3. **Finding Extension Names**: To find VS Code extension names:
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X)
   - The extension ID is shown in the extension details (e.g., `ms-python.python`)

4. **Local VSIX Files**: When using local VSIX files, provide the full path to the file as the `Name` parameter.

## Notes

- All configurations include `allowPrerelease: true` directive to support the alpha version of the Microsoft.VSCode.Dsc module (v0.1.5-alpha)
- VS Code must be installed before extensions can be managed
- Some configurations include both VS Code and VS Code Insiders installations
- Extensions are installed globally for the current user

## Related Resources

- [Microsoft.VSCode.Dsc Module Documentation](../../resources/Help/Microsoft.VSCode.Dsc/VSCodeExtension.md)
- [Visual Studio Code Extension Marketplace](https://marketplace.visualstudio.com/vscode)
- [WinGet Configuration Documentation](https://docs.microsoft.com/en-us/windows/package-manager/winget/configure)
