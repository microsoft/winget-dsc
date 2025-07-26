---
external help file: Microsoft.VSCode.Dsc.psm1-Help.xml
Module Name: Microsoft.VSCode.Dsc
ms.date: 10/22/2024
online version:
schema: 2.0.0
title: VSCodeExtension
---

# VSCodeExtension

## SYNOPSIS

Manages Visual Studio Code extensions using DSC.

## DESCRIPTION

The `VSCodeExtension` DSC Resource allows you to install, update, and remove Visual Studio Code extensions. This resource ensures that the specified Visual Studio Code extension is in the desired state.

## PARAMETERS

| **Parameter** | **Attribute** | **DataType** | **Description**                                                                                                          | **Allowed Values**                                                                                                                        |
| ------------- | ------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `Name`        | Key           | String       | The name of the Visual Studio Code extension to manage.                                                                  | To find extensions in VSCode, check out: <https://code.visualstudio.com/docs/editor/extension-marketplace#_find-and-install-an-extension> |
| `Version`     | Optional      | String       | The version of the Visual Studio Code extension to install. If not specified, the latest version will be installed.      | For example: `1.0.0`                                                                                                                      |
| `Exist`       | Optional      | Boolean      | Indicates whether the extension should exist. The default value is `$true`.                                              | `$true`, `$false`                                                                                                                         |
| `PreRelease`  | Optional      | Boolean      | Indicates whether to install the pre-release version of the extension. The default value is `$false`.                    | `$true`, `$false`                                                                                                                         |
| `Insiders`    | Optional      | Boolean      | Indicates whether to manage the extension for the Insiders version of Visual Studio Code. The default value is `$false`. | `$true`, `$false`                                                                                                                         |

## EXAMPLES

### Example 1

```powershell
# Install the latest version of the Visual Studio Code extension 'ms-python.python'
$params = @{
    Name = 'ms-python.python'
}
Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc
```

### EXAMPLE 2

```powershell
# Install a specific version of the Visual Studio Code extension 'ms-python.python'
$params = @{
    Name = 'ms-python.python'
    Version = '2021.5.842923320'
}
Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc
```

### EXAMPLE 3

```powershell
# Ensure the Visual Studio Code extension 'ms-python.python' is removed
$params = @{
    Name = 'ms-python.python'
    Exist = $false
}
Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc
```

### EXAMPLE 4

```powershell
# Ensure the Visual Studio Code extension 'ms-python.python' is removed
$params = @{
    Name = 'ms-python.python'
    Insiders = $true
}
Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc
```

### EXAMPLE 5

```powershell
$params = @{
    Name = 'dbaeumer.vscode-eslint'
    PreRelease = $true
}
Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc
```

### EXAMPLE 6

```powershell
# Install from local path
$params = @{
    Name = 'C:\SharedExtensions\ms-python.python-2021.5.842923320.vsix'
}
Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc
```
