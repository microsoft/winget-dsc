---
external help file: Microsoft.Dotnet.Dsc.psm1-Help.xml
Module Name: Microsoft.Dotnet.Dsc
ms.date: 10/22/2024
online version:
schema: 2.0.0
title: DotNetToolPackage
---

# DotNetToolPackage

## SYNOPSIS

The `DotNetToolPackage` DSC Resource allows you to install, update, and uninstall .NET tool packages using the dotnet CLI.

## DESCRIPTION

The `DotNetToolPackage` DSC Resource allows you to install, update, and uninstall .NET tool packages using the dotnet CLI.

## PARAMETERS

| **Parameter**       | **Attribute** | **DataType** | **Description**                                                                                                                                                                                                     | **Allowed Values**                 |
| ------------------- | ------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `PackageId`         | Key           | String       | The ID of the .NET tool package to manage.                                                                                                                                                                          | N/A                                |
| `Version`           | Optional      | String       | The version of the .NET tool package to install. If not specified, the latest version will be installed.                                                                                                            | N/A                                |
| `Commands`          | Optional      | String[]     | An array of commands provided by the .NET tool package.                                                                                                                                                             | N/A                                |
| `Prerelease`        | Optional      | Boolean      | Indicates whether to include prerelease versions of the .NET tool package. The default value is `$false`. Note: If the prerelease version is lower than the current version, the highest version will be installed. | `$true`, `$false`                  |
| `ToolPathDirectory` | Optional      | String       | The directory where the .NET tool package will be installed. If not specified, the package will be installed globally.                                                                                              | Use custom directory when you have |
| `Exist`             | Optional      | Boolean      | Indicates whether the package should exist. Defaults to `$true`.                                                                                                                                                    | `$true` or `$false`                |

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-DscResource -ModuleName Microsoft.DotNet.Dsc -Name DotNetToolPackage -Method Get -Property @{ PackageId = 'GitVersion.Tool' }

# This example gets the current state of the .NET tool package 'GitVersion.Tool' in the default directory.
```

### EXAMPLE 2

```powershell
Invoke-DscResource -ModuleName Microsoft.DotNet.Dsc -Name DotNetToolPackage -Method Set -Property @{
    PackageId = 'GitVersion.Tool';
    Version = '5.6.8';
}

# This example installs the .NET tool package 'GitVersion.Tool' version 5.6.8 in the default directory.
```

### EXAMPLE 3

```powershell
Invoke-DscResource -ModuleName Microsoft.DotNet.Dsc -Name DotNetToolPackage -Method Set -Property @{
    PackageId = 'PowerShell';
    Prerelease = $true;
    ToolPathDirectory = 'C:\tools';
}

# This example installs the prerelease version of the .NET tool package 'PowerShell' in the 'C:\tools' directory.
# NOTE: When the version in the feed is for example v7.4.5-preview1 and the highest is v7.4.6, the highest will be installed.
```
