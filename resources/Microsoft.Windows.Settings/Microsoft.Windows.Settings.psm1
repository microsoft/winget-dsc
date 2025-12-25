# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

enum Ensure {
    Absent
    Present
}

enum PowerPlanSettingName {
    DisplayTimeout
    SleepTimeout
}

enum PowerSource {
    # AC
    PluggedIn
    # DC
    Battery
    All
}

enum AdvancedNetworkSharingSettingName {
    NetworkDiscovery
    FileAndPrinterSharing
}

enum Action {
    NotConfigured
    Allow
    Block
}

enum Direction {
    Inbound
    Outbound
}

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:ExplorerRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'
    $global:PersonalizeRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\'
    $global:AppModelUnlockRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\'
    $global:SearchRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\'
    $global:UACRegistryPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\'
    $global:RemoteDesktopRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $global:LongPathsRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem\'
} else {
    $global:ExplorerRegistryPath = $global:PersonalizeRegistryPath = $global:AppModelUnlockRegistryPath = $global:SearchRegistryPath = $global:UACRegistryPath = $global:RemoteDesktopRegistryPath = $global:LongPathsRegistryPath = $env:TestRegistryPath
}


[DSCResource()]
class WindowsSettings {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string] $SID

    [DscProperty()]
    [string] $TaskbarAlignment

    [DscProperty()]
    [string] $AppColorMode

    [DscProperty()]
    [string] $SystemColorMode

    [DscProperty()]
    [Nullable[bool]] $DeveloperMode

    hidden [bool] $RestartExplorer = $false
    hidden [string] $TaskbarAl = 'TaskbarAl'
    hidden [string] $AppsUseLightTheme = 'AppsUseLightTheme'
    hidden [string] $SystemUsesLightTheme = 'SystemUsesLightTheme'
    hidden [string] $DeveloperModePropertyName = 'AllowDevelopmentWithoutDevLicense'

    [WindowsSettings] Get() {
        $currentState = [WindowsSettings]::new()

        # Get TaskbarAlignment
        $currentState.TaskbarAlignment = $this.GetTaskbarAlignment()

        # Get ColorMode
        $currentState.AppColorMode = $this.GetAppColorMode()
        $currentState.SystemColorMode = $this.GetSystemColorMode()

        # Get DeveloperMode
        $currentState.DeveloperMode = $this.IsDeveloperModeEnabled()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $this.TestTaskbarAlignment($currentState) -and $this.TestAppColorMode($currentState) -and $this.TestSystemColorMode($currentState) -and $this.TestDeveloperMode($currentState)
    }

    [void] Set() {
        $currentState = $this.Get()

        # Set TaskbarAlignment
        if (!$this.TestTaskbarAlignment($currentState)) {
            $desiredAlignment = $this.TaskbarAlignment -eq 'Left' ? 0 : 1
            Set-ItemProperty -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl -Value $desiredAlignment
        }

        # Set ColorMode
        $colorModeChanged = $false
        if (!$this.TestAppColorMode($currentState)) {
            $desiredColorMode = $this.AppColorMode -eq 'Dark' ? 0 : 1
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme -Value $desiredColorMode
            $colorModeChanged = $true
        }

        if (!$this.TestSystemColorMode($currentState)) {
            $desiredColorMode = $this.SystemColorMode -eq 'Dark' ? 0 : 1
            Set-ItemProperty -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme -Value $desiredColorMode
            $colorModeChanged = $true
        }

        # Notify Explorer of theme change
        if ($colorModeChanged) {
            SendImmersiveColorSetMessage
        }

        # Restart Explorer if needed
        if ($this.RestartExplorer) {
            taskkill /F /IM explorer.exe
            Start-Process explorer.exe
        }

        # Set DeveloperMode
        if (!$this.TestDeveloperMode($currentState)) {
            $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

            if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw 'Toggling Developer Mode requires this resource to be run as an Administrator.'
            }

            # 1 == enabled // 0 == disabled
            $value = $this.DeveloperMode ? 1 : 0
            Set-ItemProperty -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModePropertyName -Value $value
        }
    }

    [string] GetTaskbarAlignment() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)) {
            return 'Center'
        }

        $value = [int](Get-ItemPropertyValue -Path $global:ExplorerRegistryPath -Name $this.TaskbarAl)
        return $value -eq 0 ? 'Left' : 'Center'
    }

    [string] GetAppColorMode() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme)) {
            return 'Unknown'
        }

        $appsUseLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.AppsUseLightTheme
        if ($appsUseLightModeValue -eq 0) {
            return 'Dark'
        }

        return 'Light'
    }

    [string] GetSystemColorMode() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme)) {
            return 'Unknown'
        }

        $systemUsesLightModeValue = Get-ItemPropertyValue -Path $global:PersonalizeRegistryPath -Name $this.SystemUsesLightTheme
        if ($systemUsesLightModeValue -eq 0) {
            return 'Dark'
        }

        return 'Light'
    }

    [bool] IsDeveloperModeEnabled() {
        $regExists = DoesRegistryKeyPropertyExist -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModePropertyName

        # If the registry key does not exist, we assume developer mode is not enabled.
        if (-not($regExists)) {
            return $false
        }

        return Get-ItemPropertyValue -Path $global:AppModelUnlockRegistryPath -Name $this.DeveloperModePropertyName
    }

    [bool] TestDeveloperMode([WindowsSettings] $currentState) {
        return $this.DeveloperMode -eq $null -or $currentState.DeveloperMode -eq $this.DeveloperMode
    }

    [bool] TestTaskbarAlignment([WindowsSettings] $currentState) {
        return $this.TaskbarAlignment -eq $null -or $currentState.TaskbarAlignment -eq $this.TaskbarAlignment
    }

    [bool] TestAppColorMode([WindowsSettings] $currentState) {
        return $this.AppColorMode -eq $null -or $currentState.AppColorMode -eq $this.AppColorMode
    }

    [bool] TestSystemColorMode([WindowsSettings] $currentState) {
        return $this.SystemColorMode -eq $null -or $currentState.SystemColorMode -eq $this.SystemColorMode
    }
}

[DSCResource()]
class WindowsCapability {
    [DscProperty(Key, Mandatory)]
    [string] $Name

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [WindowsCapability] Get() {
        $currentState = [WindowsCapability]::new()
        $windowsCapability = Get-WindowsCapability -Online -Name $this.Name

        # If Name is not set in windowsCapability then the specified capability was not found
        if ([System.String]::IsNullOrEmpty($windowsCapability.Name)) {
            throw  (New-Object -TypeName System.ArgumentException -ArgumentList "$this.Name")
        } else {
            $currentState.Name = $windowsCapability.Name

            if ($windowsCapability.State -eq 'Installed') {
                $currentState.Ensure = [Ensure]::Present
            } else {
                $currentState.Ensure = [Ensure]::Absent
            }
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        # Only make changes if changes are needed
        if (-not $this.Test()) {
            if ($this.Ensure -eq [Ensure]::Present) {
                Add-WindowsCapability -Online -Name $this.Name
            } else {
                Remove-WindowsCapability -Online -Name $this.Name
            }
        }
    }
}

[DSCResource()]
class PowerPlanSetting {
    [DscProperty(Key, Mandatory)]
    [PowerPlanSettingName]$Name

    [DscProperty(Mandatory)]
    [PowerSource]$PowerSource

    [DscProperty(Mandatory)]
    [int]$SettingValue

    [DscProperty(NotConfigurable)]
    [int] $PluggedInValue

    [DscProperty(NotConfigurable)]
    [int] $BatteryValue

    [PowerPlanSetting] Get() {

        function Get-PowerPlanSetting ([PowerPlanSettingName] $SettingName) {
            begin {
                # If a power plan group policy is set, the power settings cannot be obtained, so temporarily disable it.
                $GPReg = Backup-GroupPolicyPowerPlanSetting
                if ($GPReg) {
                    Disable-GroupPolicyPowerPlanSetting
                }
            }

            process {
                $SettingGUID = ($SettingName -eq [PowerPlanSettingName]::DisplayTimeout) ? $DisplayTimeoutSettingGUID : $SleepTimeoutSettingGUID
                $PowerPlan = Get-ActivePowerPlan
                $planID = $PowerPlan.InstanceId.Split('\')[1] -replace '[{}]'

                $ReturnValue = @{
                    PlanGuid    = $planID
                    SettingGuid = $SettingGUID
                    ACValue     = ''
                    DCValue     = ''
                }

                foreach ($Power in ('AC', 'DC')) {
                    $Key = ('{0}Value' -f $Power)
                    $InstanceId = ('Microsoft:PowerSettingDataIndex\{{{0}}}\{1}\{{{2}}}' -f $planID, $Power, $SettingGUID)
                    $Instance = (Get-CimInstance -Name root\cimv2\power -Class Win32_PowerSettingDataIndex | Where-Object { $_.InstanceID -eq $InstanceId })
                    # error state
                    if (-not $Instance) { return }
                    $ReturnValue.$Key = [int]$Instance.SettingIndexValue
                }

                return $ReturnValue
            }

            end {
                if ($GPReg) {
                    # Restore the group policies
                    Restore-GroupPolicyPowerPlanSetting -GPRegArray $GPReg
                }
            }
        }

        $Setting = Get-PowerPlanSetting -SettingName $this.Name
        $this.PluggedInValue = $Setting.ACValue
        $this.BatteryValue = $Setting.DCValue

        $currentState = [PowerPlanSetting]::new()
        $currentState.Name = $this.Name
        $currentState.SettingValue = $this.SettingValue
        $currentState.PluggedInValue = $this.PluggedInValue
        $currentState.BatteryValue = $this.BatteryValue
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        # User can only specify a single setting value
        $pluggedInTest = ($currentState.PluggedInValue -eq $this.SettingValue)
        $batteryTest = ($currentState.BatteryValue -eq $this.SettingValue)

        if ($this.PowerSource -eq [PowerSource]::All) {
            return ($pluggedInTest -and $batteryTest)
        } elseif ($this.PowerSource -eq [PowerSource]::PluggedIn) {
            return $pluggedInTest
        } else {
            return $batteryTest
        }
    }

    [void] Set() {
        function Set-PowerPlanSetting ([PowerPlanSettingName] $PowerPlanSettingName, [PowerSource]$PowerSource, [int]$Value) {
            begin {
                # If a power plan group policy is set, the power settings cannot be obtained, so temporarily disable it.
                $GPReg = Backup-GroupPolicyPowerPlanSetting
                if ($GPReg) {
                    Disable-GroupPolicyPowerPlanSetting
                }
            }
            process {
                $SettingGUID = ($PowerPlanSettingName -eq [PowerPlanSettingName]::DisplayTimeout) ? $DisplayTimeoutSettingGUID : $SleepTimeoutSettingGUID
                $PowerPlan = Get-ActivePowerPlan
                $planID = $PowerPlan.InstanceId.Split('\')[1] -replace '[{}]'

                if ($PowerSource -eq [PowerSource]::All) {
                    [string[]]$Target = ('AC', 'DC')
                } elseif ($PowerSource -eq [PowerSource]::PluggedIn) {
                    [string[]]$Target = ('AC')
                } else {
                    [string[]]$Target = ('DC')
                }

                foreach ($Power in $Target) {
                    $InstanceId = ('Microsoft:PowerSettingDataIndex\{{{0}}}\{1}\{{{2}}}' -f $planID, $Power, $SettingGUID)
                    $Instance = Get-CimInstance -Name root\cimv2\power -Class Win32_PowerSettingDataIndex | Where-Object { $_.InstanceID -eq $InstanceId }
                    # error state
                    if (-not $Instance) { return }
                    $Instance | ForEach-Object { $_.SettingIndexValue = $Value }
                    Set-CimInstance -CimInstance $Instance
                }
            }
            end {
                if ($GPReg) {
                    # Restore the group policies
                    Restore-GroupPolicyPowerPlanSetting -GPRegArray $GPReg
                }
            }
        }

        if (!$this.Test()) {
            Set-PowerPlanSetting -PowerPlanSettingName $this.Name -PowerSource $this.PowerSource -Value $this.SettingValue
        }
    }
}

[DSCResource()]
class AdvancedNetworkSharingSetting {
    [DscProperty(Key, Mandatory)]
    [AdvancedNetworkSharingSettingName]$Name

    [DscProperty()]
    [string[]]$Profiles = @()

    [DscProperty(NotConfigurable)]
    [string[]]$EnabledProfiles

    # Official group names for the firewall rules
    hidden [string] $NetworkDiscoveryGroup = '@FirewallAPI.dll,-32752'
    hidden [string] $FileAndPrinterSharingGroup = '@FirewallAPI.dll,-28502'

    [AdvancedNetworkSharingSetting] Get() {
        $currentState = [AdvancedNetworkSharingSetting]::new()
        $currentState.Name = $this.Name
        $currentState.Profiles = $this.Profiles

        if ($this.Name -eq [AdvancedNetworkSharingSettingName]::NetworkDiscovery) {
            $group = $this.NetworkDiscoveryGroup
        } else {
            $group = $this.FileAndPrinterSharingGroup
        }

        # The group is enabled if all of its sub-rules are enabled and none are disabled.
        $this.EnabledProfiles = Get-NetFirewallRule -Group $group | Group-Object Profile | ForEach-Object {
            $enabled = ($_.Group.Enabled | Where-Object { $_ -eq 'true' } | Measure-Object).Count
            $disabled = ($_.Group.Enabled | Where-Object { $_ -eq 'false' } | Measure-Object).Count
            [PSCustomObject]@{
                Profile  = $_.Name
                Count    = $_.Count
                Enabled  = $enabled
                Disabled = $disabled
            }
        } | Where-Object { ($_.Enabled -gt 0) -and ($_.Disabled -eq 0) -and ($_.Enabled -eq $_.Count) } | Select-Object -Unique -CaseInsensitive -ExpandProperty Profile

        $currentState.EnabledProfiles = $this.EnabledProfiles

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        # Compare-object is case insensitive by default and does not take null arguments
        $difference = Compare-Object -ReferenceObject @( $this.Profiles | Select-Object) -DifferenceObject @( $currentState.EnabledProfiles | Select-Object)
        return -not $difference
    }

    [void] Set() {
        if (!$this.Test()) {
            if ($this.Name -eq [AdvancedNetworkSharingSettingName]::NetworkDiscovery) {
                $group = $this.NetworkDiscoveryGroup
            } else {
                $group = $this.FileAndPrinterSharingGroup
            }

            #Enable, no harm in enabling profiles if they are already enabled
            foreach ($profile in $this.Profiles) {
                Set-NetFirewallRule -Group $group -Profile $profile -Enabled True
            }

            #Disable needed if at least one profile is enabled
            $profilesToDisable = Get-NetFirewallRule -Group $group | Where-Object { ($_.Enabled -eq 'True') -and (-not $this.Profiles -contains $_.Profile ) } | Select-Object -Unique -CaseInsensitive -ExpandProperty Profile
            foreach ($profile in $profilesToDisable) {
                Set-NetFirewallRule -Group $group -Profile $profile -Enabled False
            }
        }
    }
}

[DSCResource()]
class NetConnectionProfile {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty(Mandatory)]
    [string]$InterfaceAlias

    [DscProperty(Mandatory)]
    [string]$NetworkCategory

    [NetConnectionProfile] Get() {
        $currentState = [NetConnectionProfile]::new()

        $netConnectionProfile = Get-NetConnectionProfile -InterfaceAlias $this.InterfaceAlias -ErrorAction SilentlyContinue
        if ($null -eq $netConnectionProfile) {
            throw "No network profile found for interface alias '$($this.InterfaceAlias)'"
        }

        $currentState.InterfaceAlias = $this.InterfaceAlias
        $currentState.NetworkCategory = $netConnectionProfile.NetworkCategory
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.NetworkCategory -eq $this.NetworkCategory
    }

    [void] Set() {
        if (-not $this.Test()) {
            Set-NetConnectionProfile -InterfaceAlias $this.InterfaceAlias -NetworkCategory $this.NetworkCategory
        }
    }
}

[DSCResource()]
class FirewallRule {
    [DscProperty(Key, Mandatory)]
    [string]$Name

    [DscProperty()]
    [string]$DisplayName

    [DscProperty()]
    [Action]$Action

    [DscProperty()]
    [string]$Description

    [DscProperty()]
    [Direction]$Direction

    [DscProperty()]
    [bool]$Enabled

    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty()]
    [string[]]$LocalPort

    [DscProperty()]
    [string[]]$Profiles

    [DscProperty()]
    [string]$Protocol

    [FirewallRule] Get() {
        $rule = Get-NetFirewallRule -Name $this.Name -ErrorAction SilentlyContinue

        if (-not $rule) {
            return @{
                Ensure = [Ensure]::Absent
                Name   = $this.Name
            }
        }

        $properties = $rule | GetNetFirewallPortFilter
        return @{
            Ensure      = [Ensure]::Present
            Name        = $rule.Name
            DisplayName = $rule.DisplayName
            Action      = $rule.Action
            Description = $rule.Description
            Direction   = $rule.Direction
            Enabled     = $rule.Enabled
            LocalPort   = $properties.LocalPort
            # Split the profiles string into an array
            Profiles    = ($rule.Profile -split ',') | ForEach-Object { $_.Trim() }
            Protocol    = $properties.Protocol
        }
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($this.Ensure -eq [Ensure]::Absent) {
            return $currentState.Ensure -eq [Ensure]::Absent
        }

        # Check each property only if it is specified
        if ($this.DisplayName -and ($currentState.DisplayName -ne $this.DisplayName)) {
            return $false
        }

        if ($currentState.Action -ne $this.Action) {
            return $false
        }

        if ($this.Description -and ($currentState.Description -ne $this.Description)) {
            return $false
        }

        if ($currentState.Direction -ne $this.Direction) {
            return $false
        }

        if ($currentState.Enabled -ne $this.Enabled) {
            return $false
        }

        if ($this.LocalPort -and (Compare-Object $currentState.LocalPort $this.LocalPort)) {
            return $false
        }

        if ($this.Profiles -and (Compare-Object $currentState.Profiles $this.Profiles)) {
            return $false
        }

        if ($this.Protocol -and ($currentState.Protocol -ne $this.Protocol)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        # Only make changes if changes are needed
        if (-not $this.Test()) {
            if ($this.Ensure -eq [Ensure]::Absent) {
                Remove-NetFirewallRule -Name $this.Name -ErrorAction SilentlyContinue
            } else {
                $firewallRule = Get-NetFirewallRule -Name $this.Name
                $exists = ($null -ne $firewallRule)

                $params = @{
                    # Escape firewall rule name to ensure that wildcard update is not used
                    Name        = ConvertTo-FirewallRuleNameEscapedString -Name $this.Name
                    DisplayName = $this.DisplayName
                    Action      = $this.Action.ToString()
                    Description = $this.Description
                    Direction   = $this.Direction.ToString()
                    Enabled     = $this.Enabled.ToString()
                    Profile     = $this.Profiles
                    Protocol    = $this.Protocol
                    LocalPort   = $this.LocalPort
                }

                if ($exists) {
                    <#
                        If the DisplayName is provided then need to remove it
                        And change it to NewDisplayName if it is different.
                    #>
                    if ($params.ContainsKey('DisplayName')) {
                        $null = $params.Remove('DisplayName')
                        if ($this.DisplayName -ne $FirewallRule.DisplayName) {
                            $null = $params.Add('NewDisplayName', $this.DisplayName)
                        }
                    }

                    Set-NetFirewallRule @params
                } else {
                    New-NetFirewallRule @params
                }
            }
        }
    }
}

function DoesRegistryKeyPropertyExist {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    # Get-ItemProperty will return $null if the registry key property does not exist.
    $itemProperty = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $itemProperty
}

function SendImmersiveColorSetMessage {
    param()

    Add-Type @'
using System;
using System.Runtime.InteropServices;

public class NativeMethods {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
'@

    # Constants
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    $SMTO_ABORTIFHUNG = 0x0002
    $timeout = 100
    $result = [UIntPtr]::Zero

    # Notify Explorer of theme change
    [void][NativeMethods]::SendMessageTimeout(
        $HWND_BROADCAST,
        $WM_SETTINGCHANGE,
        [UIntPtr]::Zero,
        'ImmersiveColorSet',
        $SMTO_ABORTIFHUNG,
        $timeout,
        [ref]$result
    )
}

function Get-ActivePowerPlan {
    Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan | Where-Object { $_.IsActive }
}

$SleepTimeoutSettingGUID = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
$DisplayTimeoutSettingGUID = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'

$GroupPolicyPowerPlanRegistryKeyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings'

function Backup-GroupPolicyPowerPlanSetting {
    if (Test-Path $GroupPolicyPowerPlanRegistryKeyPath) {
        $Array = @()
        Get-ChildItem $GroupPolicyPowerPlanRegistryKeyPath | ForEach-Object {
            $Path = $_.PSPath
            foreach ($Prop in $_.Property) {
                $Array += @{
                    Path  = $Path
                    Name  = $Prop
                    Value = Get-ItemPropertyValue -Path $Path -Name $Prop
                }
            }
        }
        $Array
    }
}

function Restore-GroupPolicyPowerPlanSetting([HashTable[]]$GPRegArray) {
    foreach ($Item in $GPRegArray) {
        if (-not (Test-Path $Item.Path)) {
            New-Item -Path $Item.Path -ItemType Directory -Force | Out-Null
        }
        New-ItemProperty @Item -Force | Out-Null
    }
}

function Disable-GroupPolicyPowerPlanSetting {
    Remove-Item $GroupPolicyPowerPlanRegistryKeyPath -Recurse -Force | Out-Null
}

# Convert Firewall Rule name to Escape Wildcard Characters. It will append '[', ']' and '*' with a backtick.
function ConvertTo-FirewallRuleNameEscapedString {
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        $Name
    )

    return $Name.Replace('[', '`[').Replace(']', '`]').Replace('*', '`*')
}

# Workaround mock issue for Get-NetFirewallPortFilter
function GetNetFirewallPortFilter {
    process {
        return $_ | Get-NetFirewallPortFilter
    }
}