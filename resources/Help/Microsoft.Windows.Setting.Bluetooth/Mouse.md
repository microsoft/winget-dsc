---
external help file: Microsoft.Windows.Setting.Bluetooth-Help.xml
Module Name: Microsoft.Windows.Setting.Bluetooth
ms.date: 01/19/2025
online version:
schema: 2.0.0
title: Mouse
---

# Mouse

## SYNOPSIS

The `Mouse` class is a DSC resource that allows you to manage the mouse settings on your Windows device.

## DESCRIPTION

The `Mouse` class is a DSC resource that allows you to manage the mouse settings on your Windows device.

## PARAMETERS

|      **Parameter**      | **Attribute** | **DataType**  |                                                                **Description**                                                                 |  **Allowed Values**   |
| ----------------------- | ------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `SID`                   | Key           | String        | The security identifier. This is a key property and should not be set manually.                                                                |                       |
| `PrimaryButton`         | Optional      | PrimaryButton | The primary button of the mouse. This can be either `Left` or `Right`.                                                                         | `Left` or `Right`     |
| `CursorSpeed`           | Optional      | Integer       | The cursor speed of the mouse.                                                                                                                 | Between `1` and `20`. |
| `PointerPrecision`      | Optional      | Boolean       | The pointer precision of the mouse.                                                                                                            | `$true`, `$false`     |
| `RollMouseScroll`       | Optional      | Boolean       | The roll mouse scroll of the mouse. When using in combination with `LinesToScroll`, this will enable or disable the lines to scroll at a time. | `$true`, `$false`     |
| `LinesToScroll`         | Optional      | Integer       | The number of lines to scroll. This value should be between `1` and `100`.                                                                     | Between `1` and `100` |
| `ScrollInactiveWindows` | Optional      | Boolean       | The scroll inactive windows when hovering over them.                                                                                           | `$true`, `$false`     |
| `ScrollDirection`       | Optional      | Boolean       | The motion to scroll down or up.                                                                                                               | `$true`, `$false`     |

## EXAMPLES

### EXAMPLE 1 - Set the mouse button to right

```powershell
Invoke-DscResource -Name Mouse -Method Set -Property @{ PrimaryButton = 'Right' }

# This example sets the `PrimaryButton` property to `Right`.
```

### EXAMPLE 2 - Enable the pointer precision

```powershell
Invoke-DscResource -Name Mouse -Method Set -Property @{ PointerPrecision = $true }

# This example sets the `PointerPrecision` property to `$true`.
```

### EXAMPLE 3 - Set the lines to scroll to 3

```powershell
Invoke-DscResource -Name Mouse -Method Set -Property @{ RollMouseScroll = $true; LinesToScroll = 3 }

# This example sets the `RollMouseScroll` property to `$true` and the `LinesToScroll` property to `3`.
```