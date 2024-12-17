---
external help file: NpmDsc.psm1-Help.xml
Module Name: NpmDsc
ms.date: 11/16/2024
online version:
schema: 2.0.0
title: NpmPackage
---

# NpmPackage

## SYNOPSIS

The `NpmPackage` DSC Resource allows you to manage the installation, update, and removal of npm packages. This resource ensures that the specified npm package is in the desired state.

## DESCRIPTION

The `NpmPackage` DSC Resource allows you to manage the installation, update, and removal of npm packages. This resource ensures that the specified npm package is in the desired state.

## PARAMETERS

| **Parameter**      | **Attribute**  | **DataType** | **Description**                                                                                                                    | **Allowed Values**                        |
| ------------------ | -------------- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| `Ensure`           | Optional       | String       | Specifies whether the npm package should be present or absent. The default value is `Present`.                                     | `Present`, `Absent`                       |
| `Name`             | Key, Mandatory | String       | The name of the npm package to manage. This is a key property.                                                                     | Any valid npm package name                |
| `Version`          | Optional       | String       | The version of the npm package to install. If not specified, the latest version will be installed.                                 | Any valid version string (e.g., `4.17.1`) |
| `PackageDirectory` | Optional       | String       | The directory where the npm package should be installed. If not specified, the package will be installed in the current directory. | Any valid directory path                  |
| `Global`           | Optional       | Boolean      | Indicates whether the npm package should be installed globally. The default value is `$false`.                                     | `$true`, `$false`                         |

## EXAMPLES

### EXAMPLE 1 - Install React package in default directory

```powershell
PS C:\> Invoke-DscResource -ModuleName NpmDsc -Name NpmPackage -Method Set -Property @{ Name = 'react' }

# This example installs the npm package 'react' in the current directory.
```

### EXAMPLE 2 - Install Babel package in global directory

```powershell
PS C:\> Invoke-DscResource -ModuleName NpmDsc -Name NpmPackage -Method Set -Property @{ Name = 'babel'; Global = $true }

# This example installs the npm package 'babel' globally.
```

### EXAMPLE 3 - Get WhatIf result for React package

```powershell
PS C:\> ([NpmPackage]@{ Name = 'react' }).WhatIf()

# This example returns the whatif result for installing the npm package 'react'. Note: This does not actually install the package and requires the module to be imported using 'using module <moduleName>'.
```
