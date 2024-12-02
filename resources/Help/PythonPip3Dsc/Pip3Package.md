---
external help file: PythonPip3Dsc.psm1-Help.xml
Module Name: PythonPip3Dsc
ms.date: 10/22/2024
online version:
schema: 2.0.0
title: Pip3Package
---

# PythonPip3Dsc

## SYNOPSIS

The `Pip3Package` DSC Resource allows you to install, update, and uninstall Python packages using pip3.

## DESCRIPTION

The `Pip3Package` DSC Resource allows you to install, update, and uninstall Python packages using pip3.

## PARAMETERS

| **Parameter** | **Attribute**  | **DataType** | **Description**                                                                                 | **Allowed Values**                                    |
| ------------- | -------------- | ------------ | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `SID`         | Key, Mandatory | String       | The security identifier. This is a key property and should not be set manually.                 | pack have been installed.                             |
| `Exist`       | Optional       | Boolean      | Indicates whether the package should exist. Defaults to `$true`.                                | `$true` or `$false`                                   |
| `Package`     | Mandatory      | String       | The name of the Python package to manage. This is a mandatory property.                         | For a list of Python packages, see <https://pypi.org> |
| `Version`     | Optional       | String       | The version of the Python package to manage. If not specified, the latest version will be used. | For example: `5.1.2`                                  |
| `Arguments`   | Optional       | String       | Additional arguments to pass to pip3.                                                           | Add arguments like `--debug`                          |

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-DscResource -ModuleName PythonPip3Dsc -Name Pip3Package -Method Set -Property @{ Package = 'flask' }

This example installs the Flask package.
```

### EXAMPLE 2

```powershell
Invoke-DscResource -ModuleName PythonPip3Dsc -Name Pip3Package -Method Get -Property @{ Package = 'flask'; Version = '1.1.4' }

# This example shows how to get the current state of the Flask package with version. If the version is not found, the latest version will be used if flask is found.
```

### EXAMPLE 3

```powershell
Invoke-DscResource -ModuleName PythonPip3Dsc -Name Pip3Package -Method Get -Property @{ Package = 'django'; Exist = $false }

# This example shows how Django can be removed from the system.
```
