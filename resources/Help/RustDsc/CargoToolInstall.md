---
external help file: RustDsc.psm1-Help.xml
Module Name: RustDsc
ms.date: 07/18/2025
online version:
schema: 2.0.0
title: CargoToolInstall
---

# CargoToolInstall

## SYNOPSIS

The `CargoToolInstall` DSC Resource allows you to install and uninstall Rust command-line tools using Cargo.

## DESCRIPTION

The `CargoToolInstall` DSC Resource allows you to install and uninstall Rust command-line tools globally using the `cargo install` and `cargo uninstall` commands. This resource is specifically designed for installing Rust tools that provide command-line executables, not for managing project dependencies.

## PARAMETERS

| **Parameter**      | **Attribute**   | **DataType** | **Description**                                                                                                     | **Allowed Values** |
| ------------------ | --------------- | ------------ | ------------------------------------------------------------------------------------------------------------------- | ------------------ |
| `CrateName`        | Key             | String       | The name of the Rust crate to manage as a command-line tool.                                                        | N/A                |
| `Version`          | Optional        | String       | The version of the Rust crate to install. If not specified, the latest version will be installed.                   | N/A                |
| `Exist`            | Optional        | Boolean      | Indicates whether the crate should be installed. Defaults to `$true`.                                               | `$true`, `$false`  |
| `InstalledVersion` | NotConfigurable | String       | The currently installed version of the crate. This is a read-only property that is populated during Get operations. | N/A                |

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-DscResource -ModuleName RustDsc -Name CargoToolInstall -Method Get -Property @{ CrateName = 'bat' }

# This example gets the current state of the Rust tool 'bat'.
```

### EXAMPLE 2

```powershell
Invoke-DscResource -ModuleName RustDsc -Name CargoToolInstall -Method Set -Property @{
    CrateName = 'bat'
}

# This example installs the latest version of the Rust tool 'bat' globally.
```

### EXAMPLE 3

```powershell
Invoke-DscResource -ModuleName RustDsc -Name CargoToolInstall -Method Set -Property @{
    CrateName = 'ripgrep'
    Version = '13.0.0'
}

# This example installs version 13.0.0 of the Rust tool 'ripgrep' globally.
```

### EXAMPLE 4

```powershell
Invoke-DscResource -ModuleName RustDsc -Name CargoToolInstall -Method Set -Property @{
    CrateName = 'fd-find'
    Exist = $false
}

# This example uninstalls the Rust tool 'fd-find'.
```
