# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#region Functions
function Get-VSCodeCLIPath {
    param (
        [switch]$UseInsiders
    )

    # Currently only supports user/machine install for VSCode on Windows.
    # TODO: Update this function to handle when VSCode is installed in portable mode or on macOS/Linux.

    # Determine the paths based on whether the Insiders version is used
    if ($UseInsiders) {
        $codeCLIUserPath = "$env:LocalAppData\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
        $codeCLIMachinePath = "$env:ProgramFiles\Microsoft VS Code Insiders\bin\code-insiders.cmd"
    }
    else {
        $codeCLIUserPath = "$env:LocalAppData\Programs\Microsoft VS Code\bin\code.cmd"
        $codeCLIMachinePath = "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    }

    # Check the paths and return the appropriate one
    if (Test-Path -Path $codeCLIUserPath) {
        Write-Verbose "VSCode CLI found at $codeCLIUserPath"
        return $codeCLIUserPath
    }
    elseif (Test-Path -Path $codeCLIMachinePath) {
        Write-Verbose -Message "VSCode CLI found at $codeCLIMachinePath"
        return $codeCLIMachinePath
    }
    else {
        throw "VSCode is not installed."
    }
}

function Install-VSCodeExtension {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Version
    )
    
    begin {
        function Get-VSCodeExtensionInstallArgument {
            param([string]$Name, [string]$Version)
            
            if ([string]::IsNullOrEmpty($Version)) {
                return $Name
            }

            return @(
                $Name
                $Version
            ) -join '@'
        }
    }
    
    process {
        $installArgument = Get-VSCodeExtensionInstallArgument @PSBoundParameters
        Invoke-VSCode -Command "--install-extension $installArgument"
    }
}

function Uninstall-VSCodeExtension {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name
    )
        
    Invoke-VSCode -Command "--uninstall-extension $($this.Name)"
}

function Invoke-VSCode {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    try {
        Invoke-Expression "& `"$VSCodeCLIPath`" $Command"
    }
    catch {
        throw ("Executing {0} with {$Command} failed." -f $VSCodeCLIPath)
    }
}
function Get-VSCodeSettingsFile {
    if ($IsWindows) {
        $settingsFile = Join-Path $env:APPDATA 'Code' 'User' 'settings.json'
    }
    elseif ($IsMacOS) {
        $settingsFile = Join-Path $env:HOME 'Library' 'Application Support' 'Code' 'User' 'settings.json'
    }
    elseif ($IsLinux) {
        $settingsFile = Join-Path $env:Home '.config' 'Code' 'User' 'settings.json'
    }
    else {
        throw "Unsupported platform: $Platform"
    }

    if (-not (Test-Path $settingsFile)) {
        throw "Settings file not found: $settingsFile. Please install Visual Studio Code."
    }

    return $settingsFile
}

function Test-CurrentState {
    param (
        [hashtable] $current,
        [hashtable] $props
    )

    $currentState = $true
    foreach ($property in $props.GetEnumerator()) {
        if (-not ($current.ContainsKey($property.Key))) {
            $currentState = $false
        }

        if ($current[$property.Key] -ne $property.Value) {
            $currentState = $false
        }
    }

    return $currentState
}

function Get-ClassOnlyProperty {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [hashtable] $properties
    )

    if ($properties.ContainsKey('Exist')) {
        $properties.Remove('Exist')
    }

    if ($properties.ContainsKey('SettingsFile')) {
        $properties.Remove('SettingsFile')
    }

    return $properties
}

function Get-VSCodeCurrentSettings {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [string] $settingsFile,
        [hashtable] $properties
    )

    $settings = Get-Content $settingsFile | ConvertFrom-Json

    $names = $settings | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

    $inputObject = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($name in $names) {
        $formattedName = $name
        if ($name.Contains(".")) {
            $formattedName = $name.Split(".")[1]
        }

        $format = [PSCustomObject]@{
            OriginalName  = $name
            FormattedName = $formattedName
            Value         = $settings.$name
        }
        
        $inputObject.Add($format)
    }

    $out = @{}

    foreach ($property in $properties.GetEnumerator()) {
        if ($inputObject.FormattedName -contains $property.Key) {
            $originalName = ($inputObject | Where-Object { $_.FormattedName -eq $property.Key }).OriginalName
            $out[$property.Key] = $settings.$originalName
        }
    }

    return $out
}

function Get-VSCodeWorkspaceSetting {
    param (
        [pscustomobject] $settings,
        [string] $setting,
        [object] $settingValue
    )

    $inputObject = [PSCustomObject]@{
        PropertyExist      = $true 
        PropertyValueExist = $true 
        Name               = $setting
        Settings           = $settings
    }

    if ($settings.psobject.Properties.Name -notcontains $setting) {
        $inputObject.PropertyExist = $false
    }

    if ($settings.$setting -ne $settingValue) {
        $inputObject.PropertyValueExist = $false

        $settingValue = $settings.$setting
    }

    $inputObject | Add-Member -MemberType NoteProperty -Name Value -Value $settingValue -Force

    return $inputObject
}

function Test-VSCodeWorkSpaceSetting {
    param (
        [pscustomobject] $settings,
        [string] $setting,
        [object] $settingValue
    )

    if ($settings.$setting -ne $settingValue) {
        return $false
    }

    return $true
}

function Set-VSCodeWorkSpaceSetting {
    param (
        [pscustomobject] $settings,
        [string] $setting,
        [object] $settingValue,
        [switch] $Clear
    )

    $settingsFile = Get-VSCodeSettingsFile

    $settings = Get-VSCodeWorkspaceSetting @PSBoundParameters

    $startLength = (Get-Item $settingsFile).Length

    if (-not $settings.PropertyExist -and -not $Clear) {
        if ($null -eq $settings.Settings) {
            $settings.Settings = [PSCustomObject]@{
                "$setting" = $settingValue
            }
        }
        else {
            $settings.Settings | Add-Member -MemberType NoteProperty -Name $setting -Value $settingValue -Force
        }
    }

    if (-not (Test-VSCodeWorkSpaceSetting -settings $settings.Settings -setting $setting -settingValue $settingValue) -and -not $Clear) {
        $settings.Settings.$setting = $settingValue
    }

    if ($Clear) {
        $settings.Settings.PSObject.Properties.Remove($setting)
    }

    $endLength = (Get-Item $settingsFile).Length

    if ($startLength -ne $endLength) {
        $settings.Settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding utf8
    }
}

function New-VSCodeWorkSpaceSetting {
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $true)]
        [string] $settingsFile,

        [Parameter(Mandatory = $true)]
        [string] $originalName,

        [Parameter(Mandatory = $false)]
        [hashtable] $settingTable
    )

    $settingTable = Get-ClassOnlyProperty -properties $settingTable

    foreach ($setting in $settingTable.GetEnumerator()) {
        $content = Get-Content $settingsFile | ConvertFrom-Json

        $originalSettingName = $originalName + "." + $setting.Key
        Set-VSCodeWorkSpaceSetting -settings $content -setting $originalSettingName -settingValue $setting.Value
    }
}

function Clear-VSCodeWorkspaceSetting {
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $true)]
        [string] $settingsFile,

        [Parameter(Mandatory = $false)]
        [hashtable] $settingTable
    )

    $settingTable = Get-ClassOnlyProperty -properties $settingTable

    foreach ($setting in $settingTable.GetEnumerator()) {
        $content = Get-Content $settingsFile | ConvertFrom-Json

        $originalSettingName = $originalName + "." + $setting.Key
        Set-VSCodeWorkSpaceSetting -settings $content -setting $originalSettingName -settingValue $setting.Value -Clear
    }
}
#endregion Functions

#region DSCResources
[DSCResource()]
class VSCodeExtension {
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [string] $Version

    [DscProperty()]
    [bool] $Exist = $true

    [DscProperty()]
    [bool] $UseInsiders = $false

    static [hashtable] $InstalledExtensions

    VSCodeExtension() {
    }

    VSCodeExtension([string]$Name, [string]$Version) {
        $this.Name = $Name
        $this.Version = $Version
    }

    [VSCodeExtension[]] Export([bool]$UseInsiders) {
        if ($UseInsiders) {
            $script:VSCodeCLIPath = Get-VSCodeCLIPath -UseInsiders
        }
        else {
            $script:VSCodeCLIPath = Get-VSCodeCLIPath
        }
        $extensionList = (Invoke-VSCode -Command "--list-extensions --show-versions") -Split [Environment]::NewLine

        $results = [VSCodeExtension[]]::new($extensionList.length)
        
        for ($i = 0; $i -lt $extensionList.length; $i++) {
            $extensionName, $extensionVersion = $extensionList[$i] -Split '@'
            $results[$i] = [VSCodeExtension]::new($extensionName, $extensionVersion)
        }

        return $results
    }

    [VSCodeExtension] Get() {
        [VSCodeExtension]::GetInstalledExtensions($this.UseInsiders)

        $currentState = [VSCodeExtension]::InstalledExtensions[$this.Name]
        if ($null -ne $currentState) {
            return [VSCodeExtension]::InstalledExtensions[$this.Name]
        }
        
        return [VSCodeExtension]@{
            Name        = $this.Name
            Version     = $this.Version
            Exist       = $false
            UseInsiders = $this.UseInsiders
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($currentState.Exist -ne $this.Exist) {
            return $false
        }

        if ($null -ne $this.Version -and $this.Version -ne $currentState.Version) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.Install($false)
        }
        else {
            $this.Uninstall($false)
        }
    }

    #region VSCodeExtension helper functions
    static [void] GetInstalledExtensions([bool]$UseInsiders) {   
        [VSCodeExtension]::InstalledExtensions = @{}

        $extension = [VSCodeExtension]::new()

        foreach ($extension in $extension.Export($UseInsiders)) {
            [VSCodeExtension]::InstalledExtensions[$extension.Name] = $extension
        }
    }

    [void] Install([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        Install-VSCodeExtension -Name $this.Name -Version $this.Version
        [VSCodeExtension]::GetInstalledExtensions($this.UseInsiders)
    }

    [void] Install() {
        $this.Install($true)
    }

    [void] Uninstall([bool] $preTest) {
        Uninstall-VSCodeExtension -Name $this.Name
        [VSCodeExtension]::GetInstalledExtensions($this.UseInsiders)
    }

    [void] Uninstall() {
        $this.Uninstall($true)
    }
    #endregion VSCodeExtension helper functions
}

[DscResource()]
class VSCodeAccessibilitySetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AccessibleViewCloseOnKeyPress

    [DscProperty()]
    [bool] $DebugWatchVariableAnnouncements

    [DscProperty()]
    [bool] $DimUnfocusedEnabled

    [DscProperty()]
    [double] $DimUnfocusedOpacity

    [DscProperty()]
    [bool] $HideAccessibleView

    [DscProperty()]
    [bool] $SignalOptionsDebouncePositionChanges

    [DscProperty()]
    [int] $SignalOptionsVolume

    [DscProperty()]
    [string] $SignalsChatRequestSent

    [DscProperty()]
    [string] $SignalsChatResponseReceived

    [DscProperty()]
    [string] $SignalsClear

    [DscProperty()]
    [string] $SignalsDiffLineDeleted

    [DscProperty()]
    [string] $SignalsDiffLineInserted

    [DscProperty()]
    [string] $SignalsDiffLineModified

    [DscProperty()]
    [string] $SignalsFormat

    [DscProperty()]
    [string] $SignalsLineHasBreakpoint

    [DscProperty()]
    [string] $SignalsLineHasError

    [DscProperty()]
    [string] $SignalsLineHasFoldedArea

    [DscProperty()]
    [string] $SignalsLineHasInlineSuggestion

    [DscProperty()]
    [string] $SignalsLineHasWarning

    [DscProperty()]
    [string] $SignalsNoInlayHints

    [DscProperty()]
    [string] $SignalsNotebookCellCompleted

    [DscProperty()]
    [string] $SignalsNotebookCellFailed

    [DscProperty()]
    [string] $SignalsOnDebugBreak

    [DscProperty()]
    [string] $SignalsPositionHasError

    [DscProperty()]
    [string] $SignalsPositionHasWarning

    [DscProperty()]
    [string] $SignalsProgress

    [DscProperty()]
    [string] $SignalsSave

    [DscProperty()]
    [string] $SignalsTaskCompleted

    [DscProperty()]
    [string] $SignalsTaskFailed

    [DscProperty()]
    [string] $SignalsTerminalBell

    [DscProperty()]
    [string] $SignalsTerminalCommandFailed

    [DscProperty()]
    [string] $SignalsTerminalCommandSucceeded

    [DscProperty()]
    [string] $SignalsTerminalQuickFix

    [DscProperty()]
    [string] $SignalsVoiceRecordingStarted

    [DscProperty()]
    [string] $SignalsVoiceRecordingStopped

    [DscProperty()]
    [bool] $UnderlineLinks

    [DscProperty()]
    [bool] $VerbosityComments

    [DscProperty()]
    [bool] $VerbosityDebug

    [DscProperty()]
    [bool] $VerbosityDiffEditor

    [DscProperty()]
    [bool] $VerbosityDiffEditorActive

    [DscProperty()]
    [bool] $VerbosityEmptyEditorHint

    [DscProperty()]
    [bool] $VerbosityHover

    [DscProperty()]
    [bool] $VerbosityInlineChat

    [DscProperty()]
    [bool] $VerbosityInlineCompletions

    [DscProperty()]
    [bool] $VerbosityKeybindingsEditor

    [DscProperty()]
    [bool] $VerbosityNotebook

    [DscProperty()]
    [bool] $VerbosityNotification

    [DscProperty()]
    [bool] $VerbosityPanelChat

    [DscProperty()]
    [bool] $VerbosityReplInputHint

    [DscProperty()]
    [bool] $VerbosityTerminal

    [DscProperty()]
    [bool] $VerbosityWalkthrough

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeAccessibilitySetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeAccessibilitySetting]::new($this.SettingsFile, $keys)
    }

    VSCodeAccessibilitySetting($settingsFile, $keys) {
        [VSCodeAccessibilitySetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeAccessibilitySetting] Get() {
        $current = [VSCodeAccessibilitySetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeAccessibilitySetting]::CurrentSettings

        }

        return [VSCodeAccessibilitySetting]@{
            AccessibleViewCloseOnKeyPress        = $this.AccessibleViewCloseOnKeyPress
            DebugWatchVariableAnnouncements      = $this.DebugWatchVariableAnnouncements
            DimUnfocusedEnabled                  = $this.DimUnfocusedEnabled
            DimUnfocusedOpacity                  = $this.DimUnfocusedOpacity
            HideAccessibleView                   = $this.HideAccessibleView
            SignalOptionsDebouncePositionChanges = $this.SignalOptionsDebouncePositionChanges
            SignalOptionsVolume                  = $this.SignalOptionsVolume
            SignalsChatRequestSent               = $this.SignalsChatRequestSent
            SignalsChatResponseReceived          = $this.SignalsChatResponseReceived
            SignalsClear                         = $this.SignalsClear
            SignalsDiffLineDeleted               = $this.SignalsDiffLineDeleted
            SignalsDiffLineInserted              = $this.SignalsDiffLineInserted
            SignalsDiffLineModified              = $this.SignalsDiffLineModified
            SignalsFormat                        = $this.SignalsFormat
            SignalsLineHasBreakpoint             = $this.SignalsLineHasBreakpoint
            SignalsLineHasError                  = $this.SignalsLineHasError
            SignalsLineHasFoldedArea             = $this.SignalsLineHasFoldedArea
            SignalsLineHasInlineSuggestion       = $this.SignalsLineHasInlineSuggestion
            SignalsLineHasWarning                = $this.SignalsLineHasWarning
            SignalsNoInlayHints                  = $this.SignalsNoInlayHints
            SignalsNotebookCellCompleted         = $this.SignalsNotebookCellCompleted
            SignalsNotebookCellFailed            = $this.SignalsNotebookCellFailed
            SignalsOnDebugBreak                  = $this.SignalsOnDebugBreak
            SignalsPositionHasError              = $this.SignalsPositionHasError
            SignalsPositionHasWarning            = $this.SignalsPositionHasWarning
            SignalsProgress                      = $this.SignalsProgress
            SignalsSave                          = $this.SignalsSave
            SignalsTaskCompleted                 = $this.SignalsTaskCompleted
            SignalsTaskFailed                    = $this.SignalsTaskFailed
            SignalsTerminalBell                  = $this.SignalsTerminalBell
            SignalsTerminalCommandFailed         = $this.SignalsTerminalCommandFailed
            SignalsTerminalCommandSucceeded      = $this.SignalsTerminalCommandSucceeded
            SignalsTerminalQuickFix              = $this.SignalsTerminalQuickFix
            SignalsVoiceRecordingStarted         = $this.SignalsVoiceRecordingStarted
            SignalsVoiceRecordingStopped         = $this.SignalsVoiceRecordingStopped
            UnderlineLinks                       = $this.UnderlineLinks
            VerbosityComments                    = $this.VerbosityComments
            VerbosityDebug                       = $this.VerbosityDebug
            VerbosityDiffEditor                  = $this.VerbosityDiffEditor
            VerbosityDiffEditorActive            = $this.VerbosityDiffEditorActive
            VerbosityEmptyEditorHint             = $this.VerbosityEmptyEditorHint
            VerbosityHover                       = $this.VerbosityHover
            VerbosityInlineChat                  = $this.VerbosityInlineChat
            VerbosityInlineCompletions           = $this.VerbosityInlineCompletions
            VerbosityKeybindingsEditor           = $this.VerbosityKeybindingsEditor
            VerbosityNotebook                    = $this.VerbosityNotebook
            VerbosityNotification                = $this.VerbosityNotification
            VerbosityPanelChat                   = $this.VerbosityPanelChat
            VerbosityReplInputHint               = $this.VerbosityReplInputHint
            VerbosityTerminal                    = $this.VerbosityTerminal
            VerbosityWalkthrough                 = $this.VerbosityWalkthrough
            Exist                                = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeAccessibilitySetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeAccessibilitySetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeAccessibilitySetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeAccessibilitySetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeAccessibilitySetting]::GetCurrentSettings
    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeAccessibilitySetting]::GetCurrentSettings
    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }
}


[DscResource()]
class VSCodeAddedSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $Added

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeAddedSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeAddedSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeAddedSetting($settingsFile, $keys) {
        [VSCodeAddedSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeAddedSetting] Get() {
        $current = [VSCodeAddedSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeAddedSetting]::CurrentSettings

        }

        return [VSCodeAddedSetting]@{
            Added = $this.Added
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeAddedSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeAddedSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeAddedSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeAddedSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeAddedSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeAddedSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeAnnouncementSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Announcement

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeAnnouncementSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeAnnouncementSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeAnnouncementSetting($settingsFile, $keys) {
        [VSCodeAnnouncementSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeAnnouncementSetting] Get() {
        $current = [VSCodeAnnouncementSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeAnnouncementSetting]::CurrentSettings

        }

        return [VSCodeAnnouncementSetting]@{
            Announcement = $this.Announcement
            Exist        = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeAnnouncementSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeAnnouncementSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeAnnouncementSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeAnnouncementSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeAnnouncementSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeAnnouncementSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeBashSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Bash

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeBashSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeBashSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeBashSetting($settingsFile, $keys) {
        [VSCodeBashSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeBashSetting] Get() {
        $current = [VSCodeBashSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeBashSetting]::CurrentSettings

        }

        return [VSCodeBashSetting]@{
            Bash  = $this.Bash
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeBashSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeBashSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeBashSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeBashSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeBashSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeBashSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeBreadcrumbsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $Enabled

    [DscProperty()]
    [FilePath] $FilePath = [FilePath]::On

    [DscProperty()]
    [bool] $Icons

    [DscProperty()]
    [bool] $ShowArrays

    [DscProperty()]
    [bool] $ShowBooleans

    [DscProperty()]
    [bool] $ShowClasses

    [DscProperty()]
    [bool] $ShowConstants

    [DscProperty()]
    [bool] $ShowConstructors

    [DscProperty()]
    [bool] $ShowEnumMembers

    [DscProperty()]
    [bool] $ShowEnums

    [DscProperty()]
    [bool] $ShowEvents

    [DscProperty()]
    [bool] $ShowFields

    [DscProperty()]
    [bool] $ShowFiles

    [DscProperty()]
    [bool] $ShowFunctions

    [DscProperty()]
    [bool] $ShowInterfaces

    [DscProperty()]
    [bool] $ShowKeys

    [DscProperty()]
    [bool] $ShowMethods

    [DscProperty()]
    [bool] $ShowModules

    [DscProperty()]
    [bool] $ShowNamespaces

    [DscProperty()]
    [bool] $ShowNull

    [DscProperty()]
    [bool] $ShowNumbers

    [DscProperty()]
    [bool] $ShowObjects

    [DscProperty()]
    [bool] $ShowOperators

    [DscProperty()]
    [bool] $ShowPackages

    [DscProperty()]
    [bool] $ShowProperties

    [DscProperty()]
    [bool] $ShowStrings

    [DscProperty()]
    [bool] $ShowStructs

    [DscProperty()]
    [bool] $ShowTypeParameters

    [DscProperty()]
    [bool] $ShowVariables

    [DscProperty()]
    [SymbolPath] $SymbolPath = [SymbolPath]::On

    [DscProperty()]
    [SymbolSortOrder] $SymbolSortOrder = [SymbolSortOrder]::Position

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeBreadcrumbsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeBreadcrumbsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeBreadcrumbsSetting($settingsFile, $keys) {
        [VSCodeBreadcrumbsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeBreadcrumbsSetting] Get() {
        $current = [VSCodeBreadcrumbsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeBreadcrumbsSetting]::CurrentSettings

        }

        return [VSCodeBreadcrumbsSetting]@{
            Enabled            = $this.Enabled
            FilePath           = $this.FilePath
            Icons              = $this.Icons
            ShowArrays         = $this.ShowArrays
            ShowBooleans       = $this.ShowBooleans
            ShowClasses        = $this.ShowClasses
            ShowConstants      = $this.ShowConstants
            ShowConstructors   = $this.ShowConstructors
            ShowEnumMembers    = $this.ShowEnumMembers
            ShowEnums          = $this.ShowEnums
            ShowEvents         = $this.ShowEvents
            ShowFields         = $this.ShowFields
            ShowFiles          = $this.ShowFiles
            ShowFunctions      = $this.ShowFunctions
            ShowInterfaces     = $this.ShowInterfaces
            ShowKeys           = $this.ShowKeys
            ShowMethods        = $this.ShowMethods
            ShowModules        = $this.ShowModules
            ShowNamespaces     = $this.ShowNamespaces
            ShowNull           = $this.ShowNull
            ShowNumbers        = $this.ShowNumbers
            ShowObjects        = $this.ShowObjects
            ShowOperators      = $this.ShowOperators
            ShowPackages       = $this.ShowPackages
            ShowProperties     = $this.ShowProperties
            ShowStrings        = $this.ShowStrings
            ShowStructs        = $this.ShowStructs
            ShowTypeParameters = $this.ShowTypeParameters
            ShowVariables      = $this.ShowVariables
            SymbolPath         = $this.SymbolPath
            SymbolSortOrder    = $this.SymbolSortOrder
            Exist              = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeBreadcrumbsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeBreadcrumbsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeBreadcrumbsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeBreadcrumbsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeBreadcrumbsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeBreadcrumbsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum FilePath {
    # Show the file path in the breadcrumbs view.
    On
    # Do not show the file path in the breadcrumbs view.
    Off
    # Only show the last element of the file path in the breadcrumbs view.
    Last
}

enum SymbolPath {
    # Show all symbols in the breadcrumbs view.
    On
    # Do not show symbols in the breadcrumbs view.
    Off
    # Only show the current symbol in the breadcrumbs view.
    Last
}

enum SymbolSortOrder {
    # Show symbol outline in file position order.
    Position
    # Show symbol outline in alphabetical order.
    Name
    # Show symbol outline in symbol type order.
    Type
}


[DscResource()]
class VSCodeChatSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CommandCenterEnabled

    [DscProperty()]
    [string] $EditorFontFamily

    [DscProperty()]
    [int] $EditorFontSize

    [DscProperty()]
    [string] $EditorFontWeight

    [DscProperty()]
    [int] $EditorLineHeight

    [DscProperty()]
    [string] $EditorWordWrap

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeChatSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeChatSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeChatSetting($settingsFile, $keys) {
        [VSCodeChatSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeChatSetting] Get() {
        $current = [VSCodeChatSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeChatSetting]::CurrentSettings

        }

        return [VSCodeChatSetting]@{
            CommandCenterEnabled = $this.CommandCenterEnabled
            EditorFontFamily     = $this.EditorFontFamily
            EditorFontSize       = $this.EditorFontSize
            EditorFontWeight     = $this.EditorFontWeight
            EditorLineHeight     = $this.EditorLineHeight
            EditorWordWrap       = $this.EditorWordWrap
            Exist                = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeChatSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeChatSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeChatSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeChatSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeChatSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeChatSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeCodeOutputSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CodeOutput

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeCodeOutputSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeCodeOutputSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeCodeOutputSetting($settingsFile, $keys) {
        [VSCodeCodeOutputSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeCodeOutputSetting] Get() {
        $current = [VSCodeCodeOutputSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeCodeOutputSetting]::CurrentSettings

        }

        return [VSCodeCodeOutputSetting]@{
            CodeOutput = $this.CodeOutput
            Exist      = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeCodeOutputSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeCodeOutputSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeCodeOutputSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeCodeOutputSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCodeOutputSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCodeOutputSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeCodeSourceSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CodeSource

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeCodeSourceSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeCodeSourceSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeCodeSourceSetting($settingsFile, $keys) {
        [VSCodeCodeSourceSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeCodeSourceSetting] Get() {
        $current = [VSCodeCodeSourceSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeCodeSourceSetting]::CurrentSettings

        }

        return [VSCodeCodeSourceSetting]@{
            CodeSource = $this.CodeSource
            Exist      = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeCodeSourceSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeCodeSourceSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeCodeSourceSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeCodeSourceSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCodeSourceSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCodeSourceSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeCommentsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Comments

    [DscProperty()]
    [bool] $CollapseOnResolve

    [DscProperty()]
    [bool] $MaxHeight

    [DscProperty()]
    [OpenView] $OpenView = [OpenView]::Firstfile

    [DscProperty()]
    [bool] $UseRelativeTime

    [DscProperty()]
    [bool] $Visible

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeCommentsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeCommentsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeCommentsSetting($settingsFile, $keys) {
        [VSCodeCommentsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeCommentsSetting] Get() {
        $current = [VSCodeCommentsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeCommentsSetting]::CurrentSettings

        }

        return [VSCodeCommentsSetting]@{
            Comments          = $this.Comments
            CollapseOnResolve = $this.CollapseOnResolve
            MaxHeight         = $this.MaxHeight
            OpenView          = $this.OpenView
            UseRelativeTime   = $this.UseRelativeTime
            Visible           = $this.Visible
            Exist             = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeCommentsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeCommentsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeCommentsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeCommentsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCommentsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCommentsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum OpenView {
    # The comments view will never be opened.
    Never
    # The comments view will open when a file with comments is active.
    File
    # If the comments view has not been opened yet during this session it will open the first time during a session that a file with comments is active.
    Firstfile
    # If the comments view has not been opened yet during this session and the comment is not resolved, it will open the first time during a session that a file with comments is active.
    Firstfileunresolved
}


[DscResource()]
class VSCodeCommitSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $Commit

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeCommitSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeCommitSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeCommitSetting($settingsFile, $keys) {
        [VSCodeCommitSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeCommitSetting] Get() {
        $current = [VSCodeCommitSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeCommitSetting]::CurrentSettings

        }

        return [VSCodeCommitSetting]@{
            Commit = $this.Commit
            Exist  = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeCommitSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeCommitSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeCommitSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeCommitSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCommitSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCommitSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeCompoundsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Compounds

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeCompoundsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeCompoundsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeCompoundsSetting($settingsFile, $keys) {
        [VSCodeCompoundsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeCompoundsSetting] Get() {
        $current = [VSCodeCompoundsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeCompoundsSetting]::CurrentSettings

        }

        return [VSCodeCompoundsSetting]@{
            Compounds = $this.Compounds
            Exist     = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeCompoundsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeCompoundsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeCompoundsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeCompoundsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCompoundsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCompoundsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeConfigurationsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Configurations

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeConfigurationsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeConfigurationsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeConfigurationsSetting($settingsFile, $keys) {
        [VSCodeConfigurationsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeConfigurationsSetting] Get() {
        $current = [VSCodeConfigurationsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeConfigurationsSetting]::CurrentSettings

        }

        return [VSCodeConfigurationsSetting]@{
            Configurations = $this.Configurations
            Exist          = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeConfigurationsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeConfigurationsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeConfigurationsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeConfigurationsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeConfigurationsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeConfigurationsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeCssSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CompletionCompletePropertyWithSemicolon

    [DscProperty()]
    [bool] $CompletionTriggerPropertyValueCompletion

    [DscProperty()]
    [string] $CustomData

    [DscProperty()]
    [string] $FormatBraceStyle

    [DscProperty()]
    [bool] $FormatEnable

    [DscProperty()]
    [string] $FormatMaxPreserveNewLines

    [DscProperty()]
    [bool] $FormatNewlineBetweenRules

    [DscProperty()]
    [bool] $FormatNewlineBetweenSelectors

    [DscProperty()]
    [bool] $FormatPreserveNewLines

    [DscProperty()]
    [bool] $FormatSpaceAroundSelectorSeparator

    [DscProperty()]
    [bool] $HoverDocumentation

    [DscProperty()]
    [bool] $HoverReferences

    [DscProperty()]
    [string] $LintArgumentsInColorFunction

    [DscProperty()]
    [string] $LintBoxModel

    [DscProperty()]
    [string] $LintCompatibleVendorPrefixes

    [DscProperty()]
    [string] $LintDuplicateProperties

    [DscProperty()]
    [string] $LintEmptyRules

    [DscProperty()]
    [string] $LintFloat

    [DscProperty()]
    [string] $LintFontFaceProperties

    [DscProperty()]
    [string] $LintHexColorLength

    [DscProperty()]
    [string] $LintIdSelector

    [DscProperty()]
    [string] $LintIeHack

    [DscProperty()]
    [string] $LintImportant

    [DscProperty()]
    [string] $LintImportStatement

    [DscProperty()]
    [string] $LintPropertyIgnoredDueToDisplay

    [DscProperty()]
    [string] $LintUniversalSelector

    [DscProperty()]
    [string] $LintUnknownAtRules

    [DscProperty()]
    [string] $LintUnknownProperties

    [DscProperty()]
    [string] $LintUnknownVendorSpecificProperties

    [DscProperty()]
    [string] $LintValidProperties

    [DscProperty()]
    [string] $LintVendorPrefix

    [DscProperty()]
    [string] $LintZeroUnits

    [DscProperty()]
    [string] $TraceServer

    [DscProperty()]
    [bool] $Validate

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeCssSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeCssSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeCssSetting($settingsFile, $keys) {
        [VSCodeCssSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeCssSetting] Get() {
        $current = [VSCodeCssSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeCssSetting]::CurrentSettings

        }

        return [VSCodeCssSetting]@{
            CompletionCompletePropertyWithSemicolon  = $this.CompletionCompletePropertyWithSemicolon
            CompletionTriggerPropertyValueCompletion = $this.CompletionTriggerPropertyValueCompletion
            CustomData                               = $this.CustomData
            FormatBraceStyle                         = $this.FormatBraceStyle
            FormatEnable                             = $this.FormatEnable
            FormatMaxPreserveNewLines                = $this.FormatMaxPreserveNewLines
            FormatNewlineBetweenRules                = $this.FormatNewlineBetweenRules
            FormatNewlineBetweenSelectors            = $this.FormatNewlineBetweenSelectors
            FormatPreserveNewLines                   = $this.FormatPreserveNewLines
            FormatSpaceAroundSelectorSeparator       = $this.FormatSpaceAroundSelectorSeparator
            HoverDocumentation                       = $this.HoverDocumentation
            HoverReferences                          = $this.HoverReferences
            LintArgumentsInColorFunction             = $this.LintArgumentsInColorFunction
            LintBoxModel                             = $this.LintBoxModel
            LintCompatibleVendorPrefixes             = $this.LintCompatibleVendorPrefixes
            LintDuplicateProperties                  = $this.LintDuplicateProperties
            LintEmptyRules                           = $this.LintEmptyRules
            LintFloat                                = $this.LintFloat
            LintFontFaceProperties                   = $this.LintFontFaceProperties
            LintHexColorLength                       = $this.LintHexColorLength
            LintIdSelector                           = $this.LintIdSelector
            LintIeHack                               = $this.LintIeHack
            LintImportant                            = $this.LintImportant
            LintImportStatement                      = $this.LintImportStatement
            LintPropertyIgnoredDueToDisplay          = $this.LintPropertyIgnoredDueToDisplay
            LintUniversalSelector                    = $this.LintUniversalSelector
            LintUnknownAtRules                       = $this.LintUnknownAtRules
            LintUnknownProperties                    = $this.LintUnknownProperties
            LintUnknownVendorSpecificProperties      = $this.LintUnknownVendorSpecificProperties
            LintValidProperties                      = $this.LintValidProperties
            LintVendorPrefix                         = $this.LintVendorPrefix
            LintZeroUnits                            = $this.LintZeroUnits
            TraceServer                              = $this.TraceServer
            Validate                                 = $this.Validate
            Exist                                    = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeCssSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeCssSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeCssSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeCssSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCssSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeCssSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeDebugSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AllowBreakpointsEverywhere

    [DscProperty()]
    [AutoExpandLazyVariables] $AutoExpandLazyVariables = [AutoExpandLazyVariables]::Auto

    [DscProperty()]
    [bool] $CloseReadonlyTabsOnEnd

    [DscProperty()]
    [ConfirmOnExit] $ConfirmOnExit = [ConfirmOnExit]::Never

    [DscProperty()]
    [string] $ConsoleAcceptSuggestionOnEnter

    [DscProperty()]
    [bool] $ConsoleCloseOnEnd

    [DscProperty()]
    [bool] $ConsoleCollapseIdenticalLines

    [DscProperty()]
    [string] $ConsoleFontFamily

    [DscProperty()]
    [int] $ConsoleFontSize

    [DscProperty()]
    [bool] $ConsoleHistorySuggestions

    [DscProperty()]
    [int] $ConsoleLineHeight

    [DscProperty()]
    [bool] $ConsoleWordWrap

    [DscProperty()]
    [bool] $DisassemblyViewShowSourceCode

    [DscProperty()]
    [bool] $EnableStatusBarColor

    [DscProperty()]
    [bool] $FocusEditorOnBreak

    [DscProperty()]
    [bool] $FocusWindowOnBreak

    [DscProperty()]
    [GutterMiddleClickAction] $GutterMiddleClickAction = [GutterMiddleClickAction]::Logpoint

    [DscProperty()]
    [bool] $HideLauncherWhileDebugging

    [DscProperty()]
    [InlineValues] $InlineValues = [InlineValues]::Auto

    [DscProperty()]
    [string] $InternalConsoleOptions

    [DscProperty()]
    [JavascriptAutoAttachFilter] $JavascriptAutoAttachFilter = [JavascriptAutoAttachFilter]::Disabled

    [DscProperty()]
    [string] $JavascriptAutoAttachSmartPattern

    [DscProperty()]
    [bool] $JavascriptAutomaticallyTunnelRemoteServer

    [DscProperty()]
    [bool] $JavascriptBreakOnConditionalError

    [DscProperty()]
    [string] $JavascriptCodelensNpmScripts

    [DscProperty()]
    [string] $JavascriptDebugByLinkOptions

    [DscProperty()]
    [string] $JavascriptDefaultRuntimeExecutable

    [DscProperty()]
    [string] $JavascriptPickAndAttachOptions

    [DscProperty()]
    [string] $JavascriptResourceRequestOptions

    [DscProperty()]
    [string] $JavascriptTerminalOptions

    [DscProperty()]
    [bool] $JavascriptUnmapMissingSources

    [DscProperty()]
    [OnTaskErrors] $OnTaskErrors = [OnTaskErrors]::Prompt

    [DscProperty()]
    [string] $OpenDebug

    [DscProperty()]
    [bool] $OpenExplorerOnEnd

    [DscProperty()]
    [SaveBeforeStart] $SaveBeforeStart = [SaveBeforeStart]::Alleditorsinactivegroup

    [DscProperty()]
    [bool] $ShowBreakpointsInOverviewRuler

    [DscProperty()]
    [bool] $ShowInlineBreakpointCandidates

    [DscProperty()]
    [ShowInStatusBar] $ShowInStatusBar = [ShowInStatusBar]::Onfirstsessionstart

    [DscProperty()]
    [bool] $ShowSubSessionsInToolBar

    [DscProperty()]
    [bool] $ShowVariableTypes

    [DscProperty()]
    [bool] $TerminalClearBeforeReusing

    [DscProperty()]
    [ToolBarLocation] $ToolBarLocation = [ToolBarLocation]::Floating

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeDebugSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeDebugSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeDebugSetting($settingsFile, $keys) {
        [VSCodeDebugSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeDebugSetting] Get() {
        $current = [VSCodeDebugSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeDebugSetting]::CurrentSettings

        }

        return [VSCodeDebugSetting]@{
            AllowBreakpointsEverywhere                = $this.AllowBreakpointsEverywhere
            AutoExpandLazyVariables                   = $this.AutoExpandLazyVariables
            CloseReadonlyTabsOnEnd                    = $this.CloseReadonlyTabsOnEnd
            ConfirmOnExit                             = $this.ConfirmOnExit
            ConsoleAcceptSuggestionOnEnter            = $this.ConsoleAcceptSuggestionOnEnter
            ConsoleCloseOnEnd                         = $this.ConsoleCloseOnEnd
            ConsoleCollapseIdenticalLines             = $this.ConsoleCollapseIdenticalLines
            ConsoleFontFamily                         = $this.ConsoleFontFamily
            ConsoleFontSize                           = $this.ConsoleFontSize
            ConsoleHistorySuggestions                 = $this.ConsoleHistorySuggestions
            ConsoleLineHeight                         = $this.ConsoleLineHeight
            ConsoleWordWrap                           = $this.ConsoleWordWrap
            DisassemblyViewShowSourceCode             = $this.DisassemblyViewShowSourceCode
            EnableStatusBarColor                      = $this.EnableStatusBarColor
            FocusEditorOnBreak                        = $this.FocusEditorOnBreak
            FocusWindowOnBreak                        = $this.FocusWindowOnBreak
            GutterMiddleClickAction                   = $this.GutterMiddleClickAction
            HideLauncherWhileDebugging                = $this.HideLauncherWhileDebugging
            InlineValues                              = $this.InlineValues
            InternalConsoleOptions                    = $this.InternalConsoleOptions
            JavascriptAutoAttachFilter                = $this.JavascriptAutoAttachFilter
            JavascriptAutoAttachSmartPattern          = $this.JavascriptAutoAttachSmartPattern
            JavascriptAutomaticallyTunnelRemoteServer = $this.JavascriptAutomaticallyTunnelRemoteServer
            JavascriptBreakOnConditionalError         = $this.JavascriptBreakOnConditionalError
            JavascriptCodelensNpmScripts              = $this.JavascriptCodelensNpmScripts
            JavascriptDebugByLinkOptions              = $this.JavascriptDebugByLinkOptions
            JavascriptDefaultRuntimeExecutable        = $this.JavascriptDefaultRuntimeExecutable
            JavascriptPickAndAttachOptions            = $this.JavascriptPickAndAttachOptions
            JavascriptResourceRequestOptions          = $this.JavascriptResourceRequestOptions
            JavascriptTerminalOptions                 = $this.JavascriptTerminalOptions
            JavascriptUnmapMissingSources             = $this.JavascriptUnmapMissingSources
            OnTaskErrors                              = $this.OnTaskErrors
            OpenDebug                                 = $this.OpenDebug
            OpenExplorerOnEnd                         = $this.OpenExplorerOnEnd
            SaveBeforeStart                           = $this.SaveBeforeStart
            ShowBreakpointsInOverviewRuler            = $this.ShowBreakpointsInOverviewRuler
            ShowInlineBreakpointCandidates            = $this.ShowInlineBreakpointCandidates
            ShowInStatusBar                           = $this.ShowInStatusBar
            ShowSubSessionsInToolBar                  = $this.ShowSubSessionsInToolBar
            ShowVariableTypes                         = $this.ShowVariableTypes
            TerminalClearBeforeReusing                = $this.TerminalClearBeforeReusing
            ToolBarLocation                           = $this.ToolBarLocation
            Exist                                     = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeDebugSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeDebugSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeDebugSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeDebugSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeDebugSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeDebugSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum AutoExpandLazyVariables {
    # When in screen reader optimized mode, automatically expand lazy variables.
    Auto
    # Always automatically expand lazy variables.
    On
    # Never automatically expand lazy variables.
    Off
}

enum ConfirmOnExit {
    # Never confirm.
    Never
    # Always confirm if there are debug sessions.
    Always
}

enum GutterMiddleClickAction {
    # Add Logpoint.
    Logpoint
    # Add Conditional Breakpoint.
    Conditionalbreakpoint
    # Add Triggered Breakpoint.
    Triggeredbreakpoint
    # Don't perform any action.
    None
}

enum InlineValues {
    # Always show variable values inline in editor while debugging.
    On
    # Never show variable values inline in editor while debugging.
    Off
    # Show variable values inline in editor while debugging when the language supports inline value locations.
    Auto
}

enum JavascriptAutoAttachFilter {
    # Auto attach to every Node.js process launched in the terminal.
    Always
    # Auto attach when running scripts that aren't in a node_modules folder.
    Smart
    # Only auto attach when the `--inspect` is given.
    Onlywithflag
    # Auto attach is disabled and not shown in status bar.
    Disabled
}

enum OnTaskErrors {
    # Ignore task errors and start debugging.
    Debuganyway
    # Show the Problems view and do not start debugging.
    Showerrors
    # Prompt user.
    Prompt
    # Cancel debugging.
    Abort
}

enum SaveBeforeStart {
    # Save all editors in the active group before starting a debug session.
    Alleditorsinactivegroup
    # Save all editors in the active group except untitled ones before starting a debug session.
    Nonuntitlededitorsinactivegroup
    # Don't save any editors before starting a debug session.
    None
}

enum ShowInStatusBar {
    # Never show debug in Status bar
    Never
    # Always show debug in Status bar
    Always
    # Show debug in Status bar only after debug was started for the first time
    Onfirstsessionstart
}

enum ToolBarLocation {
    # Show debug toolbar in all views.
    Floating
    # Show debug toolbar only in debug views.
    Docked
    # `(Experimental)` Show debug toolbar in the command center.
    Commandcenter
    # Do not show debug toolbar.
    Hidden
}


[DscResource()]
class VSCodeDefaultSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $Default

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeDefaultSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeDefaultSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeDefaultSetting($settingsFile, $keys) {
        [VSCodeDefaultSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeDefaultSetting] Get() {
        $current = [VSCodeDefaultSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeDefaultSetting]::CurrentSettings

        }

        return [VSCodeDefaultSetting]@{
            Default = $this.Default
            Exist   = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeDefaultSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeDefaultSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeDefaultSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeDefaultSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeDefaultSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeDefaultSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeDiffEditorSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CodeLens

    [DscProperty()]
    [DiffAlgorithm] $DiffAlgorithm = [DiffAlgorithm]::Advanced

    [DscProperty()]
    [int] $HideUnchangedRegionsContextLineCount

    [DscProperty()]
    [bool] $HideUnchangedRegionsEnabled

    [DscProperty()]
    [int] $HideUnchangedRegionsMinimumLineCount

    [DscProperty()]
    [int] $HideUnchangedRegionsRevealLineCount

    [DscProperty()]
    [bool] $IgnoreTrimWhitespace

    [DscProperty()]
    [int] $MaxComputationTime

    [DscProperty()]
    [int] $MaxFileSize

    [DscProperty()]
    [bool] $RenderGutterMenu

    [DscProperty()]
    [bool] $RenderIndicators

    [DscProperty()]
    [bool] $RenderMarginRevertIcon

    [DscProperty()]
    [bool] $RenderSideBySide

    [DscProperty()]
    [int] $RenderSideBySideInlineBreakpoint

    [DscProperty()]
    [bool] $UseInlineViewWhenSpaceIsLimited

    [DscProperty()]
    [WordWrap] $WordWrap = [WordWrap]::Inherit

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeDiffEditorSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeDiffEditorSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeDiffEditorSetting($settingsFile, $keys) {
        [VSCodeDiffEditorSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeDiffEditorSetting] Get() {
        $current = [VSCodeDiffEditorSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeDiffEditorSetting]::CurrentSettings

        }

        return [VSCodeDiffEditorSetting]@{
            CodeLens                             = $this.CodeLens
            DiffAlgorithm                        = $this.DiffAlgorithm
            HideUnchangedRegionsContextLineCount = $this.HideUnchangedRegionsContextLineCount
            HideUnchangedRegionsEnabled          = $this.HideUnchangedRegionsEnabled
            HideUnchangedRegionsMinimumLineCount = $this.HideUnchangedRegionsMinimumLineCount
            HideUnchangedRegionsRevealLineCount  = $this.HideUnchangedRegionsRevealLineCount
            IgnoreTrimWhitespace                 = $this.IgnoreTrimWhitespace
            MaxComputationTime                   = $this.MaxComputationTime
            MaxFileSize                          = $this.MaxFileSize
            RenderGutterMenu                     = $this.RenderGutterMenu
            RenderIndicators                     = $this.RenderIndicators
            RenderMarginRevertIcon               = $this.RenderMarginRevertIcon
            RenderSideBySide                     = $this.RenderSideBySide
            RenderSideBySideInlineBreakpoint     = $this.RenderSideBySideInlineBreakpoint
            UseInlineViewWhenSpaceIsLimited      = $this.UseInlineViewWhenSpaceIsLimited
            WordWrap                             = $this.WordWrap
            Exist                                = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeDiffEditorSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeDiffEditorSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeDiffEditorSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeDiffEditorSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeDiffEditorSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeDiffEditorSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum DiffAlgorithm {
    # Uses the legacy diffing algorithm.
    Legacy
    # Uses the advanced diffing algorithm.
    Advanced
}

enum WordWrap {
    # Lines will never wrap.
    Off
    # Lines will wrap at the viewport width.
    On
    # Lines will wrap according to the `editor.wordWrap` setting.
    Inherit
}


[DscResource()]
class VSCodeEditorSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AcceptSuggestionOnCommitCharacter

    [DscProperty()]
    [AcceptSuggestionOnEnter] $AcceptSuggestionOnEnter = [AcceptSuggestionOnEnter]::On

    [DscProperty()]
    [int] $AccessibilityPageSize

    [DscProperty()]
    [AccessibilitySupport] $AccessibilitySupport = [AccessibilitySupport]::Auto

    [DscProperty()]
    [AutoClosingBrackets] $AutoClosingBrackets = [AutoClosingBrackets]::Languagedefined

    [DscProperty()]
    [AutoClosingComments] $AutoClosingComments = [AutoClosingComments]::Languagedefined

    [DscProperty()]
    [AutoClosingDelete] $AutoClosingDelete = [AutoClosingDelete]::Auto

    [DscProperty()]
    [AutoClosingOvertype] $AutoClosingOvertype = [AutoClosingOvertype]::Auto

    [DscProperty()]
    [AutoClosingQuotes] $AutoClosingQuotes = [AutoClosingQuotes]::Languagedefined

    [DscProperty()]
    [string] $AutoIndent

    [DscProperty()]
    [AutoSurround] $AutoSurround = [AutoSurround]::Languagedefined

    [DscProperty()]
    [string] $Background

    [DscProperty()]
    [bool] $BracketPairColorizationEnabled

    [DscProperty()]
    [bool] $BracketPairColorizationIndependentColorPoolPerBracketType

    [DscProperty()]
    [bool] $CodeActionsTriggerOnFocusChange

    [DscProperty()]
    [string] $CodeActionsOnSave

    [DscProperty()]
    [bool] $CodeActionWidgetIncludeNearbyQuickFixes

    [DscProperty()]
    [bool] $CodeActionWidgetShowHeaders

    [DscProperty()]
    [bool] $CodeLens

    [DscProperty()]
    [string] $CodeLensFontFamily

    [DscProperty()]
    [int] $CodeLensFontSize

    [DscProperty()]
    [bool] $ColorDecorators

    [DscProperty()]
    [ColorDecoratorsActivatedOn] $ColorDecoratorsActivatedOn = [ColorDecoratorsActivatedOn]::Clickandhover

    [DscProperty()]
    [int] $ColorDecoratorsLimit

    [DscProperty()]
    [bool] $ColumnSelection

    [DscProperty()]
    [bool] $CommentsIgnoreEmptyLines

    [DscProperty()]
    [bool] $CommentsInsertSpace

    [DscProperty()]
    [bool] $CopyWithSyntaxHighlighting

    [DscProperty()]
    [string] $CursorBlinking

    [DscProperty()]
    [CursorSmoothCaretAnimation] $CursorSmoothCaretAnimation = [CursorSmoothCaretAnimation]::Off

    [DscProperty()]
    [string] $CursorStyle

    [DscProperty()]
    [int] $CursorSurroundingLines

    [DscProperty()]
    [CursorSurroundingLinesStyle] $CursorSurroundingLinesStyle = [CursorSurroundingLinesStyle]::Default

    [DscProperty()]
    [int] $CursorWidth

    [DscProperty()]
    [bool] $DefaultColorDecorators

    [DscProperty()]
    [string] $DefaultFoldingRangeProvider

    [DscProperty()]
    [string] $DefaultFormatter

    [DscProperty()]
    [bool] $DefinitionLinkOpensInPeek

    [DscProperty()]
    [bool] $DetectIndentation

    [DscProperty()]
    [bool] $DragAndDrop

    [DscProperty()]
    [bool] $DropIntoEditorEnabled

    [DscProperty()]
    [DropIntoEditorShowDropSelector] $DropIntoEditorShowDropSelector = [DropIntoEditorShowDropSelector]::Afterdrop

    [DscProperty()]
    [bool] $EmptySelectionClipboard

    [DscProperty()]
    [int] $FastScrollSensitivity

    [DscProperty()]
    [bool] $FindAddExtraSpaceOnTop

    [DscProperty()]
    [FindAutoFindInSelection] $FindAutoFindInSelection = [FindAutoFindInSelection]::Never

    [DscProperty()]
    [bool] $FindCursorMoveOnType

    [DscProperty()]
    [bool] $FindGlobalFindClipboard

    [DscProperty()]
    [bool] $FindLoop

    [DscProperty()]
    [FindSeedSearchStringFromSelection] $FindSeedSearchStringFromSelection = [FindSeedSearchStringFromSelection]::Always

    [DscProperty()]
    [bool] $Folding

    [DscProperty()]
    [bool] $FoldingHighlight

    [DscProperty()]
    [bool] $FoldingImportsByDefault

    [DscProperty()]
    [int] $FoldingMaximumRegions

    [DscProperty()]
    [FoldingStrategy] $FoldingStrategy = [FoldingStrategy]::Auto

    [DscProperty()]
    [string] $FontFamily

    [DscProperty()]
    [bool] $FontLigatures

    [DscProperty()]
    [int] $FontSize

    [DscProperty()]
    [bool] $FontVariations

    [DscProperty()]
    [string] $FontWeight

    [DscProperty()]
    [string] $Foreground

    [DscProperty()]
    [bool] $FormatOnPaste

    [DscProperty()]
    [bool] $FormatOnSave

    [DscProperty()]
    [FormatOnSaveMode] $FormatOnSaveMode = [FormatOnSaveMode]::File

    [DscProperty()]
    [bool] $FormatOnType

    [DscProperty()]
    [bool] $GlyphMargin

    [DscProperty()]
    [string] $GotoLocationAlternativeDeclarationCommand

    [DscProperty()]
    [string] $GotoLocationAlternativeDefinitionCommand

    [DscProperty()]
    [string] $GotoLocationAlternativeImplementationCommand

    [DscProperty()]
    [string] $GotoLocationAlternativeReferenceCommand

    [DscProperty()]
    [string] $GotoLocationAlternativeTypeDefinitionCommand

    [DscProperty()]
    [GotoLocationMultipleDeclarations] $GotoLocationMultipleDeclarations = [GotoLocationMultipleDeclarations]::Peek

    [DscProperty()]
    [GotoLocationMultipleDefinitions] $GotoLocationMultipleDefinitions = [GotoLocationMultipleDefinitions]::Peek

    [DscProperty()]
    [GotoLocationMultipleImplementations] $GotoLocationMultipleImplementations = [GotoLocationMultipleImplementations]::Peek

    [DscProperty()]
    [GotoLocationMultipleReferences] $GotoLocationMultipleReferences = [GotoLocationMultipleReferences]::Peek

    [DscProperty()]
    [GotoLocationMultipleTypeDefinitions] $GotoLocationMultipleTypeDefinitions = [GotoLocationMultipleTypeDefinitions]::Peek

    [DscProperty()]
    [GuidesBracketPairs] $GuidesBracketPairs = [GuidesBracketPairs]::False

    [DscProperty()]
    [GuidesBracketPairsHorizontal] $GuidesBracketPairsHorizontal = [GuidesBracketPairsHorizontal]::Active

    [DscProperty()]
    [bool] $GuidesHighlightActiveBracketPair

    [DscProperty()]
    [GuidesHighlightActiveIndentation] $GuidesHighlightActiveIndentation = [GuidesHighlightActiveIndentation]::True

    [DscProperty()]
    [bool] $GuidesIndentation

    [DscProperty()]
    [bool] $HideCursorInOverviewRuler

    [DscProperty()]
    [bool] $HoverAbove

    [DscProperty()]
    [int] $HoverDelay

    [DscProperty()]
    [bool] $HoverEnabled

    [DscProperty()]
    [int] $HoverHidingDelay

    [DscProperty()]
    [bool] $HoverSticky

    [DscProperty()]
    [string] $IndentSize

    [DscProperty()]
    [InlayHintsEnabled] $InlayHintsEnabled = [InlayHintsEnabled]::On

    [DscProperty()]
    [string] $InlayHintsFontFamily

    [DscProperty()]
    [int] $InlayHintsFontSize

    [DscProperty()]
    [int] $InlayHintsMaximumLength

    [DscProperty()]
    [bool] $InlayHintsPadding

    [DscProperty()]
    [bool] $InlineCompletionsAccessibilityVerbose

    [DscProperty()]
    [bool] $InlineSuggestEnabled

    [DscProperty()]
    [string] $InlineSuggestFontFamily

    [DscProperty()]
    [InlineSuggestShowToolbar] $InlineSuggestShowToolbar = [InlineSuggestShowToolbar]::Onhover

    [DscProperty()]
    [bool] $InlineSuggestSuppressSuggestions

    [DscProperty()]
    [bool] $InlineSuggestSyntaxHighlightingEnabled

    [DscProperty()]
    [bool] $InsertSpaces

    [DscProperty()]
    [string] $LanguageBrackets

    [DscProperty()]
    [string] $LanguageColorizedBracketPairs

    [DscProperty()]
    [bool] $LargeFileOptimizations

    [DscProperty()]
    [int] $LetterSpacing

    [DscProperty()]
    [LightbulbEnabled] $LightbulbEnabled = [LightbulbEnabled]::Oncode

    [DscProperty()]
    [int] $LineHeight

    [DscProperty()]
    [LineNumbers] $LineNumbers = [LineNumbers]::On

    [DscProperty()]
    [bool] $LinkedEditing

    [DscProperty()]
    [bool] $Links

    [DscProperty()]
    [string] $MatchBrackets

    [DscProperty()]
    [int] $MaxTokenizationLineLength

    [DscProperty()]
    [bool] $MinimapAutohide

    [DscProperty()]
    [bool] $MinimapEnabled

    [DscProperty()]
    [int] $MinimapMaxColumn

    [DscProperty()]
    [bool] $MinimapRenderCharacters

    [DscProperty()]
    [int] $MinimapScale

    [DscProperty()]
    [int] $MinimapSectionHeaderFontSize

    [DscProperty()]
    [int] $MinimapSectionHeaderLetterSpacing

    [DscProperty()]
    [bool] $MinimapShowMarkSectionHeaders

    [DscProperty()]
    [bool] $MinimapShowRegionSectionHeaders

    [DscProperty()]
    [string] $MinimapShowSlider

    [DscProperty()]
    [string] $MinimapSide

    [DscProperty()]
    [MinimapSize] $MinimapSize = [MinimapSize]::Proportional

    [DscProperty()]
    [int] $MouseWheelScrollSensitivity

    [DscProperty()]
    [bool] $MouseWheelZoom

    [DscProperty()]
    [int] $MultiCursorLimit

    [DscProperty()]
    [bool] $MultiCursorMergeOverlapping

    [DscProperty()]
    [MultiCursorModifier] $MultiCursorModifier = [MultiCursorModifier]::Alt

    [DscProperty()]
    [MultiCursorPaste] $MultiCursorPaste = [MultiCursorPaste]::Spread

    [DscProperty()]
    [OccurrencesHighlight] $OccurrencesHighlight = [OccurrencesHighlight]::Singlefile

    [DscProperty()]
    [bool] $OverviewRulerBorder

    [DscProperty()]
    [int] $PaddingBottom

    [DscProperty()]
    [int] $PaddingTop

    [DscProperty()]
    [bool] $ParameterHintsCycle

    [DscProperty()]
    [bool] $ParameterHintsEnabled

    [DscProperty()]
    [bool] $PasteAsEnabled

    [DscProperty()]
    [PasteAsShowPasteSelector] $PasteAsShowPasteSelector = [PasteAsShowPasteSelector]::Afterpaste

    [DscProperty()]
    [PeekWidgetDefaultFocus] $PeekWidgetDefaultFocus = [PeekWidgetDefaultFocus]::Tree

    [DscProperty()]
    [string] $QuickSuggestions

    [DscProperty()]
    [int] $QuickSuggestionsDelay

    [DscProperty()]
    [bool] $RenameEnablePreview

    [DscProperty()]
    [bool] $RenderControlCharacters

    [DscProperty()]
    [string] $RenderFinalNewline

    [DscProperty()]
    [RenderLineHighlight] $RenderLineHighlight = [RenderLineHighlight]::Line

    [DscProperty()]
    [bool] $RenderLineHighlightOnlyWhenFocus

    [DscProperty()]
    [RenderWhitespace] $RenderWhitespace = [RenderWhitespace]::Selection

    [DscProperty()]
    [bool] $RoundedSelection

    [DscProperty()]
    [string] $Rulers

    [DscProperty()]
    [bool] $ScreenReaderAnnounceInlineSuggestion

    [DscProperty()]
    [ScrollbarHorizontal] $ScrollbarHorizontal = [ScrollbarHorizontal]::Auto

    [DscProperty()]
    [int] $ScrollbarHorizontalScrollbarSize

    [DscProperty()]
    [bool] $ScrollbarIgnoreHorizontalScrollbarInContentHeight

    [DscProperty()]
    [bool] $ScrollbarScrollByPage

    [DscProperty()]
    [ScrollbarVertical] $ScrollbarVertical = [ScrollbarVertical]::Auto

    [DscProperty()]
    [int] $ScrollbarVerticalScrollbarSize

    [DscProperty()]
    [int] $ScrollBeyondLastColumn

    [DscProperty()]
    [bool] $ScrollBeyondLastLine

    [DscProperty()]
    [bool] $ScrollPredominantAxis

    [DscProperty()]
    [string] $SelectionBackground

    [DscProperty()]
    [bool] $SelectionClipboard

    [DscProperty()]
    [bool] $SelectionHighlight

    [DscProperty()]
    [SemanticHighlightingEnabled] $SemanticHighlightingEnabled = [SemanticHighlightingEnabled]::Configuredbytheme

    [DscProperty()]
    [string] $SemanticTokenColorCustomizations

    [DscProperty()]
    [bool] $ShowDeprecated

    [DscProperty()]
    [ShowFoldingControls] $ShowFoldingControls = [ShowFoldingControls]::Mouseover

    [DscProperty()]
    [bool] $ShowUnused

    [DscProperty()]
    [bool] $SmartSelectSelectLeadingAndTrailingWhitespace

    [DscProperty()]
    [bool] $SmartSelectSelectSubwords

    [DscProperty()]
    [bool] $SmoothScrolling

    [DscProperty()]
    [bool] $SnippetsCodeActionsEnabled

    [DscProperty()]
    [SnippetSuggestions] $SnippetSuggestions = [SnippetSuggestions]::Inline

    [DscProperty()]
    [bool] $StablePeek

    [DscProperty()]
    [string] $StickyScrollDefaultModel

    [DscProperty()]
    [bool] $StickyScrollEnabled

    [DscProperty()]
    [int] $StickyScrollMaxLineCount

    [DscProperty()]
    [bool] $StickyScrollScrollWithEditor

    [DscProperty()]
    [bool] $StickyTabStops

    [DscProperty()]
    [bool] $SuggestFilterGraceful

    [DscProperty()]
    [string] $SuggestInsertMode

    [DscProperty()]
    [bool] $SuggestLocalityBonus

    [DscProperty()]
    [bool] $SuggestMatchOnWordStartOnly

    [DscProperty()]
    [bool] $SuggestPreview

    [DscProperty()]
    [SuggestSelectionMode] $SuggestSelectionMode = [SuggestSelectionMode]::Always

    [DscProperty()]
    [bool] $SuggestShareSuggestSelections

    [DscProperty()]
    [bool] $SuggestShowClasses

    [DscProperty()]
    [bool] $SuggestShowColors

    [DscProperty()]
    [bool] $SuggestShowConstants

    [DscProperty()]
    [bool] $SuggestShowConstructors

    [DscProperty()]
    [bool] $SuggestShowCustomcolors

    [DscProperty()]
    [bool] $SuggestShowDeprecated

    [DscProperty()]
    [bool] $SuggestShowEnumMembers

    [DscProperty()]
    [bool] $SuggestShowEnums

    [DscProperty()]
    [bool] $SuggestShowEvents

    [DscProperty()]
    [bool] $SuggestShowFields

    [DscProperty()]
    [bool] $SuggestShowFiles

    [DscProperty()]
    [bool] $SuggestShowFolders

    [DscProperty()]
    [bool] $SuggestShowFunctions

    [DscProperty()]
    [bool] $SuggestShowIcons

    [DscProperty()]
    [bool] $SuggestShowInlineDetails

    [DscProperty()]
    [bool] $SuggestShowInterfaces

    [DscProperty()]
    [bool] $SuggestShowIssues

    [DscProperty()]
    [bool] $SuggestShowKeywords

    [DscProperty()]
    [bool] $SuggestShowMethods

    [DscProperty()]
    [bool] $SuggestShowModules

    [DscProperty()]
    [bool] $SuggestShowOperators

    [DscProperty()]
    [bool] $SuggestShowProperties

    [DscProperty()]
    [bool] $SuggestShowReferences

    [DscProperty()]
    [bool] $SuggestShowSnippets

    [DscProperty()]
    [bool] $SuggestShowStatusBar

    [DscProperty()]
    [bool] $SuggestShowStructs

    [DscProperty()]
    [bool] $SuggestShowTypeParameters

    [DscProperty()]
    [bool] $SuggestShowUnits

    [DscProperty()]
    [bool] $SuggestShowUsers

    [DscProperty()]
    [bool] $SuggestShowValues

    [DscProperty()]
    [bool] $SuggestShowVariables

    [DscProperty()]
    [bool] $SuggestShowWords

    [DscProperty()]
    [bool] $SuggestSnippetsPreventQuickSuggestions

    [DscProperty()]
    [int] $SuggestFontSize

    [DscProperty()]
    [int] $SuggestLineHeight

    [DscProperty()]
    [bool] $SuggestOnTriggerCharacters

    [DscProperty()]
    [SuggestSelection] $SuggestSelection = [SuggestSelection]::First

    [DscProperty()]
    [TabCompletion] $TabCompletion = [TabCompletion]::Off

    [DscProperty()]
    [bool] $TabFocusMode

    [DscProperty()]
    [int] $TabSize

    [DscProperty()]
    [string] $TokenColorCustomizations

    [DscProperty()]
    [bool] $TrimAutoWhitespace

    [DscProperty()]
    [bool] $UnfoldOnClickAfterEndOfLine

    [DscProperty()]
    [string] $UnicodeHighlightAllowedCharacters

    [DscProperty()]
    [string] $UnicodeHighlightAllowedLocales

    [DscProperty()]
    [bool] $UnicodeHighlightAmbiguousCharacters

    [DscProperty()]
    [string] $UnicodeHighlightIncludeComments

    [DscProperty()]
    [bool] $UnicodeHighlightIncludeStrings

    [DscProperty()]
    [bool] $UnicodeHighlightInvisibleCharacters

    [DscProperty()]
    [string] $UnicodeHighlightNonBasicASCII

    [DscProperty()]
    [UnusualLineTerminators] $UnusualLineTerminators = [UnusualLineTerminators]::Prompt

    [DscProperty()]
    [bool] $UseTabStops

    [DscProperty()]
    [WordBasedSuggestions] $WordBasedSuggestions = [WordBasedSuggestions]::Matchingdocuments

    [DscProperty()]
    [WordBreak] $WordBreak = [WordBreak]::Normal

    [DscProperty()]
    [string] $WordSegmenterLocales

    [DscProperty()]
    [string] $WordSeparators

    [DscProperty()]
    [string] $WordWrap

    [DscProperty()]
    [int] $WordWrapColumn

    [DscProperty()]
    [WrappingIndent] $WrappingIndent = [WrappingIndent]::Same

    [DscProperty()]
    [WrappingStrategy] $WrappingStrategy = [WrappingStrategy]::Simple

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeEditorSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeEditorSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeEditorSetting($settingsFile, $keys) {
        [VSCodeEditorSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeEditorSetting] Get() {
        $current = [VSCodeEditorSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeEditorSetting]::CurrentSettings

        }

        return [VSCodeEditorSetting]@{
            AcceptSuggestionOnCommitCharacter                         = $this.AcceptSuggestionOnCommitCharacter
            AcceptSuggestionOnEnter                                   = $this.AcceptSuggestionOnEnter
            AccessibilityPageSize                                     = $this.AccessibilityPageSize
            AccessibilitySupport                                      = $this.AccessibilitySupport
            AutoClosingBrackets                                       = $this.AutoClosingBrackets
            AutoClosingComments                                       = $this.AutoClosingComments
            AutoClosingDelete                                         = $this.AutoClosingDelete
            AutoClosingOvertype                                       = $this.AutoClosingOvertype
            AutoClosingQuotes                                         = $this.AutoClosingQuotes
            AutoIndent                                                = $this.AutoIndent
            AutoSurround                                              = $this.AutoSurround
            Background                                                = $this.Background
            BracketPairColorizationEnabled                            = $this.BracketPairColorizationEnabled
            BracketPairColorizationIndependentColorPoolPerBracketType = $this.BracketPairColorizationIndependentColorPoolPerBracketType
            CodeActionsTriggerOnFocusChange                           = $this.CodeActionsTriggerOnFocusChange
            CodeActionsOnSave                                         = $this.CodeActionsOnSave
            CodeActionWidgetIncludeNearbyQuickFixes                   = $this.CodeActionWidgetIncludeNearbyQuickFixes
            CodeActionWidgetShowHeaders                               = $this.CodeActionWidgetShowHeaders
            CodeLens                                                  = $this.CodeLens
            CodeLensFontFamily                                        = $this.CodeLensFontFamily
            CodeLensFontSize                                          = $this.CodeLensFontSize
            ColorDecorators                                           = $this.ColorDecorators
            ColorDecoratorsActivatedOn                                = $this.ColorDecoratorsActivatedOn
            ColorDecoratorsLimit                                      = $this.ColorDecoratorsLimit
            ColumnSelection                                           = $this.ColumnSelection
            CommentsIgnoreEmptyLines                                  = $this.CommentsIgnoreEmptyLines
            CommentsInsertSpace                                       = $this.CommentsInsertSpace
            CopyWithSyntaxHighlighting                                = $this.CopyWithSyntaxHighlighting
            CursorBlinking                                            = $this.CursorBlinking
            CursorSmoothCaretAnimation                                = $this.CursorSmoothCaretAnimation
            CursorStyle                                               = $this.CursorStyle
            CursorSurroundingLines                                    = $this.CursorSurroundingLines
            CursorSurroundingLinesStyle                               = $this.CursorSurroundingLinesStyle
            CursorWidth                                               = $this.CursorWidth
            DefaultColorDecorators                                    = $this.DefaultColorDecorators
            DefaultFoldingRangeProvider                               = $this.DefaultFoldingRangeProvider
            DefaultFormatter                                          = $this.DefaultFormatter
            DefinitionLinkOpensInPeek                                 = $this.DefinitionLinkOpensInPeek
            DetectIndentation                                         = $this.DetectIndentation
            DragAndDrop                                               = $this.DragAndDrop
            DropIntoEditorEnabled                                     = $this.DropIntoEditorEnabled
            DropIntoEditorShowDropSelector                            = $this.DropIntoEditorShowDropSelector
            EmptySelectionClipboard                                   = $this.EmptySelectionClipboard
            FastScrollSensitivity                                     = $this.FastScrollSensitivity
            FindAddExtraSpaceOnTop                                    = $this.FindAddExtraSpaceOnTop
            FindAutoFindInSelection                                   = $this.FindAutoFindInSelection
            FindCursorMoveOnType                                      = $this.FindCursorMoveOnType
            FindGlobalFindClipboard                                   = $this.FindGlobalFindClipboard
            FindLoop                                                  = $this.FindLoop
            FindSeedSearchStringFromSelection                         = $this.FindSeedSearchStringFromSelection
            Folding                                                   = $this.Folding
            FoldingHighlight                                          = $this.FoldingHighlight
            FoldingImportsByDefault                                   = $this.FoldingImportsByDefault
            FoldingMaximumRegions                                     = $this.FoldingMaximumRegions
            FoldingStrategy                                           = $this.FoldingStrategy
            FontFamily                                                = $this.FontFamily
            FontLigatures                                             = $this.FontLigatures
            FontSize                                                  = $this.FontSize
            FontVariations                                            = $this.FontVariations
            FontWeight                                                = $this.FontWeight
            Foreground                                                = $this.Foreground
            FormatOnPaste                                             = $this.FormatOnPaste
            FormatOnSave                                              = $this.FormatOnSave
            FormatOnSaveMode                                          = $this.FormatOnSaveMode
            FormatOnType                                              = $this.FormatOnType
            GlyphMargin                                               = $this.GlyphMargin
            GotoLocationAlternativeDeclarationCommand                 = $this.GotoLocationAlternativeDeclarationCommand
            GotoLocationAlternativeDefinitionCommand                  = $this.GotoLocationAlternativeDefinitionCommand
            GotoLocationAlternativeImplementationCommand              = $this.GotoLocationAlternativeImplementationCommand
            GotoLocationAlternativeReferenceCommand                   = $this.GotoLocationAlternativeReferenceCommand
            GotoLocationAlternativeTypeDefinitionCommand              = $this.GotoLocationAlternativeTypeDefinitionCommand
            GotoLocationMultipleDeclarations                          = $this.GotoLocationMultipleDeclarations
            GotoLocationMultipleDefinitions                           = $this.GotoLocationMultipleDefinitions
            GotoLocationMultipleImplementations                       = $this.GotoLocationMultipleImplementations
            GotoLocationMultipleReferences                            = $this.GotoLocationMultipleReferences
            GotoLocationMultipleTypeDefinitions                       = $this.GotoLocationMultipleTypeDefinitions
            GuidesBracketPairs                                        = $this.GuidesBracketPairs
            GuidesBracketPairsHorizontal                              = $this.GuidesBracketPairsHorizontal
            GuidesHighlightActiveBracketPair                          = $this.GuidesHighlightActiveBracketPair
            GuidesHighlightActiveIndentation                          = $this.GuidesHighlightActiveIndentation
            GuidesIndentation                                         = $this.GuidesIndentation
            HideCursorInOverviewRuler                                 = $this.HideCursorInOverviewRuler
            HoverAbove                                                = $this.HoverAbove
            HoverDelay                                                = $this.HoverDelay
            HoverEnabled                                              = $this.HoverEnabled
            HoverHidingDelay                                          = $this.HoverHidingDelay
            HoverSticky                                               = $this.HoverSticky
            IndentSize                                                = $this.IndentSize
            InlayHintsEnabled                                         = $this.InlayHintsEnabled
            InlayHintsFontFamily                                      = $this.InlayHintsFontFamily
            InlayHintsFontSize                                        = $this.InlayHintsFontSize
            InlayHintsMaximumLength                                   = $this.InlayHintsMaximumLength
            InlayHintsPadding                                         = $this.InlayHintsPadding
            InlineCompletionsAccessibilityVerbose                     = $this.InlineCompletionsAccessibilityVerbose
            InlineSuggestEnabled                                      = $this.InlineSuggestEnabled
            InlineSuggestFontFamily                                   = $this.InlineSuggestFontFamily
            InlineSuggestShowToolbar                                  = $this.InlineSuggestShowToolbar
            InlineSuggestSuppressSuggestions                          = $this.InlineSuggestSuppressSuggestions
            InlineSuggestSyntaxHighlightingEnabled                    = $this.InlineSuggestSyntaxHighlightingEnabled
            InsertSpaces                                              = $this.InsertSpaces
            LanguageBrackets                                          = $this.LanguageBrackets
            LanguageColorizedBracketPairs                             = $this.LanguageColorizedBracketPairs
            LargeFileOptimizations                                    = $this.LargeFileOptimizations
            LetterSpacing                                             = $this.LetterSpacing
            LightbulbEnabled                                          = $this.LightbulbEnabled
            LineHeight                                                = $this.LineHeight
            LineNumbers                                               = $this.LineNumbers
            LinkedEditing                                             = $this.LinkedEditing
            Links                                                     = $this.Links
            MatchBrackets                                             = $this.MatchBrackets
            MaxTokenizationLineLength                                 = $this.MaxTokenizationLineLength
            MinimapAutohide                                           = $this.MinimapAutohide
            MinimapEnabled                                            = $this.MinimapEnabled
            MinimapMaxColumn                                          = $this.MinimapMaxColumn
            MinimapRenderCharacters                                   = $this.MinimapRenderCharacters
            MinimapScale                                              = $this.MinimapScale
            MinimapSectionHeaderFontSize                              = $this.MinimapSectionHeaderFontSize
            MinimapSectionHeaderLetterSpacing                         = $this.MinimapSectionHeaderLetterSpacing
            MinimapShowMarkSectionHeaders                             = $this.MinimapShowMarkSectionHeaders
            MinimapShowRegionSectionHeaders                           = $this.MinimapShowRegionSectionHeaders
            MinimapShowSlider                                         = $this.MinimapShowSlider
            MinimapSide                                               = $this.MinimapSide
            MinimapSize                                               = $this.MinimapSize
            MouseWheelScrollSensitivity                               = $this.MouseWheelScrollSensitivity
            MouseWheelZoom                                            = $this.MouseWheelZoom
            MultiCursorLimit                                          = $this.MultiCursorLimit
            MultiCursorMergeOverlapping                               = $this.MultiCursorMergeOverlapping
            MultiCursorModifier                                       = $this.MultiCursorModifier
            MultiCursorPaste                                          = $this.MultiCursorPaste
            OccurrencesHighlight                                      = $this.OccurrencesHighlight
            OverviewRulerBorder                                       = $this.OverviewRulerBorder
            PaddingBottom                                             = $this.PaddingBottom
            PaddingTop                                                = $this.PaddingTop
            ParameterHintsCycle                                       = $this.ParameterHintsCycle
            ParameterHintsEnabled                                     = $this.ParameterHintsEnabled
            PasteAsEnabled                                            = $this.PasteAsEnabled
            PasteAsShowPasteSelector                                  = $this.PasteAsShowPasteSelector
            PeekWidgetDefaultFocus                                    = $this.PeekWidgetDefaultFocus
            QuickSuggestions                                          = $this.QuickSuggestions
            QuickSuggestionsDelay                                     = $this.QuickSuggestionsDelay
            RenameEnablePreview                                       = $this.RenameEnablePreview
            RenderControlCharacters                                   = $this.RenderControlCharacters
            RenderFinalNewline                                        = $this.RenderFinalNewline
            RenderLineHighlight                                       = $this.RenderLineHighlight
            RenderLineHighlightOnlyWhenFocus                          = $this.RenderLineHighlightOnlyWhenFocus
            RenderWhitespace                                          = $this.RenderWhitespace
            RoundedSelection                                          = $this.RoundedSelection
            Rulers                                                    = $this.Rulers
            ScreenReaderAnnounceInlineSuggestion                      = $this.ScreenReaderAnnounceInlineSuggestion
            ScrollbarHorizontal                                       = $this.ScrollbarHorizontal
            ScrollbarHorizontalScrollbarSize                          = $this.ScrollbarHorizontalScrollbarSize
            ScrollbarIgnoreHorizontalScrollbarInContentHeight         = $this.ScrollbarIgnoreHorizontalScrollbarInContentHeight
            ScrollbarScrollByPage                                     = $this.ScrollbarScrollByPage
            ScrollbarVertical                                         = $this.ScrollbarVertical
            ScrollbarVerticalScrollbarSize                            = $this.ScrollbarVerticalScrollbarSize
            ScrollBeyondLastColumn                                    = $this.ScrollBeyondLastColumn
            ScrollBeyondLastLine                                      = $this.ScrollBeyondLastLine
            ScrollPredominantAxis                                     = $this.ScrollPredominantAxis
            SelectionBackground                                       = $this.SelectionBackground
            SelectionClipboard                                        = $this.SelectionClipboard
            SelectionHighlight                                        = $this.SelectionHighlight
            SemanticHighlightingEnabled                               = $this.SemanticHighlightingEnabled
            SemanticTokenColorCustomizations                          = $this.SemanticTokenColorCustomizations
            ShowDeprecated                                            = $this.ShowDeprecated
            ShowFoldingControls                                       = $this.ShowFoldingControls
            ShowUnused                                                = $this.ShowUnused
            SmartSelectSelectLeadingAndTrailingWhitespace             = $this.SmartSelectSelectLeadingAndTrailingWhitespace
            SmartSelectSelectSubwords                                 = $this.SmartSelectSelectSubwords
            SmoothScrolling                                           = $this.SmoothScrolling
            SnippetsCodeActionsEnabled                                = $this.SnippetsCodeActionsEnabled
            SnippetSuggestions                                        = $this.SnippetSuggestions
            StablePeek                                                = $this.StablePeek
            StickyScrollDefaultModel                                  = $this.StickyScrollDefaultModel
            StickyScrollEnabled                                       = $this.StickyScrollEnabled
            StickyScrollMaxLineCount                                  = $this.StickyScrollMaxLineCount
            StickyScrollScrollWithEditor                              = $this.StickyScrollScrollWithEditor
            StickyTabStops                                            = $this.StickyTabStops
            SuggestFilterGraceful                                     = $this.SuggestFilterGraceful
            SuggestInsertMode                                         = $this.SuggestInsertMode
            SuggestLocalityBonus                                      = $this.SuggestLocalityBonus
            SuggestMatchOnWordStartOnly                               = $this.SuggestMatchOnWordStartOnly
            SuggestPreview                                            = $this.SuggestPreview
            SuggestSelectionMode                                      = $this.SuggestSelectionMode
            SuggestShareSuggestSelections                             = $this.SuggestShareSuggestSelections
            SuggestShowClasses                                        = $this.SuggestShowClasses
            SuggestShowColors                                         = $this.SuggestShowColors
            SuggestShowConstants                                      = $this.SuggestShowConstants
            SuggestShowConstructors                                   = $this.SuggestShowConstructors
            SuggestShowCustomcolors                                   = $this.SuggestShowCustomcolors
            SuggestShowDeprecated                                     = $this.SuggestShowDeprecated
            SuggestShowEnumMembers                                    = $this.SuggestShowEnumMembers
            SuggestShowEnums                                          = $this.SuggestShowEnums
            SuggestShowEvents                                         = $this.SuggestShowEvents
            SuggestShowFields                                         = $this.SuggestShowFields
            SuggestShowFiles                                          = $this.SuggestShowFiles
            SuggestShowFolders                                        = $this.SuggestShowFolders
            SuggestShowFunctions                                      = $this.SuggestShowFunctions
            SuggestShowIcons                                          = $this.SuggestShowIcons
            SuggestShowInlineDetails                                  = $this.SuggestShowInlineDetails
            SuggestShowInterfaces                                     = $this.SuggestShowInterfaces
            SuggestShowIssues                                         = $this.SuggestShowIssues
            SuggestShowKeywords                                       = $this.SuggestShowKeywords
            SuggestShowMethods                                        = $this.SuggestShowMethods
            SuggestShowModules                                        = $this.SuggestShowModules
            SuggestShowOperators                                      = $this.SuggestShowOperators
            SuggestShowProperties                                     = $this.SuggestShowProperties
            SuggestShowReferences                                     = $this.SuggestShowReferences
            SuggestShowSnippets                                       = $this.SuggestShowSnippets
            SuggestShowStatusBar                                      = $this.SuggestShowStatusBar
            SuggestShowStructs                                        = $this.SuggestShowStructs
            SuggestShowTypeParameters                                 = $this.SuggestShowTypeParameters
            SuggestShowUnits                                          = $this.SuggestShowUnits
            SuggestShowUsers                                          = $this.SuggestShowUsers
            SuggestShowValues                                         = $this.SuggestShowValues
            SuggestShowVariables                                      = $this.SuggestShowVariables
            SuggestShowWords                                          = $this.SuggestShowWords
            SuggestSnippetsPreventQuickSuggestions                    = $this.SuggestSnippetsPreventQuickSuggestions
            SuggestFontSize                                           = $this.SuggestFontSize
            SuggestLineHeight                                         = $this.SuggestLineHeight
            SuggestOnTriggerCharacters                                = $this.SuggestOnTriggerCharacters
            SuggestSelection                                          = $this.SuggestSelection
            TabCompletion                                             = $this.TabCompletion
            TabFocusMode                                              = $this.TabFocusMode
            TabSize                                                   = $this.TabSize
            TokenColorCustomizations                                  = $this.TokenColorCustomizations
            TrimAutoWhitespace                                        = $this.TrimAutoWhitespace
            UnfoldOnClickAfterEndOfLine                               = $this.UnfoldOnClickAfterEndOfLine
            UnicodeHighlightAllowedCharacters                         = $this.UnicodeHighlightAllowedCharacters
            UnicodeHighlightAllowedLocales                            = $this.UnicodeHighlightAllowedLocales
            UnicodeHighlightAmbiguousCharacters                       = $this.UnicodeHighlightAmbiguousCharacters
            UnicodeHighlightIncludeComments                           = $this.UnicodeHighlightIncludeComments
            UnicodeHighlightIncludeStrings                            = $this.UnicodeHighlightIncludeStrings
            UnicodeHighlightInvisibleCharacters                       = $this.UnicodeHighlightInvisibleCharacters
            UnicodeHighlightNonBasicASCII                             = $this.UnicodeHighlightNonBasicASCII
            UnusualLineTerminators                                    = $this.UnusualLineTerminators
            UseTabStops                                               = $this.UseTabStops
            WordBasedSuggestions                                      = $this.WordBasedSuggestions
            WordBreak                                                 = $this.WordBreak
            WordSegmenterLocales                                      = $this.WordSegmenterLocales
            WordSeparators                                            = $this.WordSeparators
            WordWrap                                                  = $this.WordWrap
            WordWrapColumn                                            = $this.WordWrapColumn
            WrappingIndent                                            = $this.WrappingIndent
            WrappingStrategy                                          = $this.WrappingStrategy
            Exist                                                     = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeEditorSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeEditorSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeEditorSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeEditorSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeEditorSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeEditorSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum AcceptSuggestionOnEnter {
    # Only accept a suggestion with `Enter` when it makes a textual change.
    Smart
}

enum AccessibilitySupport {
    # Use platform APIs to detect when a Screen Reader is attached.
    Auto
    # Optimize for usage with a Screen Reader.
    On
    # Assume a screen reader is not attached.
    Off
}

enum AutoClosingBrackets {
    # Use language configurations to determine when to autoclose brackets.
    Languagedefined
    # Autoclose brackets only when the cursor is to the left of whitespace.
    Beforewhitespace
}

enum AutoClosingComments {
    # Use language configurations to determine when to autoclose comments.
    Languagedefined
    # Autoclose comments only when the cursor is to the left of whitespace.
    Beforewhitespace
}

enum AutoClosingDelete {
    # Remove adjacent closing quotes or brackets only if they were automatically inserted.
    Auto
}

enum AutoClosingOvertype {
    # Type over closing quotes or brackets only if they were automatically inserted.
    Auto
}

enum AutoClosingQuotes {
    # Use language configurations to determine when to autoclose quotes.
    Languagedefined
    # Autoclose quotes only when the cursor is to the left of whitespace.
    Beforewhitespace
}

enum AutoSurround {
    # Use language configurations to determine when to automatically surround selections.
    Languagedefined
    # Surround with quotes but not brackets.
    Quotes
    # Surround with brackets but not quotes.
    Brackets
}

enum ColorDecoratorsActivatedOn {
    # Make the color picker appear both on click and hover of the color decorator
    Clickandhover
    # Make the color picker appear on hover of the color decorator
    Hover
    # Make the color picker appear on click of the color decorator
    Click
}

enum CursorSmoothCaretAnimation {
    # Smooth caret animation is disabled.
    Off
    # Smooth caret animation is enabled only when the user moves the cursor with an explicit gesture.
    Explicit
    # Smooth caret animation is always enabled.
    On
}

enum CursorSurroundingLinesStyle {
    # `cursorSurroundingLines` is enforced only when triggered via the keyboard or API.
    Default
    # `cursorSurroundingLines` is enforced always.
    All
}

enum DropIntoEditorShowDropSelector {
    # Show the drop selector widget after a file is dropped into the editor.
    Afterdrop
    # Never show the drop selector widget. Instead the default drop provider is always used.
    Never
}

enum FindAutoFindInSelection {
    # Never turn on Find in Selection automatically (default).
    Never
    # Always turn on Find in Selection automatically.
    Always
    # Turn on Find in Selection automatically when multiple lines of content are selected.
    Multiline
}

enum FindSeedSearchStringFromSelection {
    # Never seed search string from the editor selection.
    Never
    # Always seed search string from the editor selection, including word at cursor position.
    Always
    # Only seed search string from the editor selection.
    Selection
}

enum FoldingStrategy {
    # Use a language-specific folding strategy if available, else the indentation-based one.
    Auto
    # Use the indentation-based folding strategy.
    Indentation
}

enum FormatOnSaveMode {
    # Format the whole file.
    File
    # Format modifications (requires source control).
    Modifications
    # Will attempt to format modifications only (requires source control). If source control can't be used, then the whole file will be formatted.
    Modificationsifavailable
}

enum GotoLocationMultipleDeclarations {
    # Show Peek view of the results (default)
    Peek
    # Go to the primary result and show a Peek view
    Gotoandpeek
    # Go to the primary result and enable Peek-less navigation to others
    Goto
}

enum GotoLocationMultipleDefinitions {
    # Show Peek view of the results (default)
    Peek
    # Go to the primary result and show a Peek view
    Gotoandpeek
    # Go to the primary result and enable Peek-less navigation to others
    Goto
}

enum GotoLocationMultipleImplementations {
    # Show Peek view of the results (default)
    Peek
    # Go to the primary result and show a Peek view
    Gotoandpeek
    # Go to the primary result and enable Peek-less navigation to others
    Goto
}

enum GotoLocationMultipleReferences {
    # Show Peek view of the results (default)
    Peek
    # Go to the primary result and show a Peek view
    Gotoandpeek
    # Go to the primary result and enable Peek-less navigation to others
    Goto
}

enum GotoLocationMultipleTypeDefinitions {
    # Show Peek view of the results (default)
    Peek
    # Go to the primary result and show a Peek view
    Gotoandpeek
    # Go to the primary result and enable Peek-less navigation to others
    Goto
}

enum GuidesBracketPairs {
    # Enables bracket pair guides.
    True
    # Enables bracket pair guides only for the active bracket pair.
    Active
    # Disables bracket pair guides.
    False
}

enum GuidesBracketPairsHorizontal {
    # Enables horizontal guides as addition to vertical bracket pair guides.
    True
    # Enables horizontal guides only for the active bracket pair.
    Active
    # Disables horizontal bracket pair guides.
    False
}

enum GuidesHighlightActiveIndentation {
    # Highlights the active indent guide.
    True
    # Highlights the active indent guide even if bracket guides are highlighted.
    Always
    # Do not highlight the active indent guide.
    False
}

enum InlayHintsEnabled {
    # Inlay hints are enabled
    On
    # Inlay hints are showing by default and hide when holding Ctrl+Alt
    Onunlesspressed
    # Inlay hints are hidden by default and show when holding Ctrl+Alt
    Offunlesspressed
    # Inlay hints are disabled
    Off
}

enum InlineSuggestShowToolbar {
    # Show the inline suggestion toolbar whenever an inline suggestion is shown.
    Always
    # Show the inline suggestion toolbar when hovering over an inline suggestion.
    Onhover
    # Never show the inline suggestion toolbar.
    Never
}

enum LightbulbEnabled {
    # Disable the code action menu.
    Off
    # Show the code action menu when the cursor is on lines with code.
    Oncode
    # Show the code action menu when the cursor is on lines with code or on empty lines.
    On
}

enum LineNumbers {
    # Line numbers are not rendered.
    Off
    # Line numbers are rendered as absolute number.
    On
    # Line numbers are rendered as distance in lines to cursor position.
    Relative
    # Line numbers are rendered every 10 lines.
    Interval
}

enum MinimapSize {
    # The minimap has the same size as the editor contents (and might scroll).
    Proportional
    # The minimap will stretch or shrink as necessary to fill the height of the editor (no scrolling).
    Fill
    # The minimap will shrink as necessary to never be larger than the editor (no scrolling).
    Fit
}

enum MultiCursorModifier {
    # Maps to `Control` on Windows and Linux and to `Command` on macOS.
    Ctrlcmd
    # Maps to `Alt` on Windows and Linux and to `Option` on macOS.
    Alt
}

enum MultiCursorPaste {
    # Each cursor pastes a single line of the text.
    Spread
    # Each cursor pastes the full text.
    Full
}

enum OccurrencesHighlight {
    # Does not highlight occurrences.
    Off
    # Highlights occurrences only in the current file.
    Singlefile
    # Experimental: Highlights occurrences across all valid open files.
    Multifile
}

enum PasteAsShowPasteSelector {
    # Show the paste selector widget after content is pasted into the editor.
    Afterpaste
    # Never show the paste selector widget. Instead the default pasting behavior is always used.
    Never
}

enum PeekWidgetDefaultFocus {
    # Focus the tree when opening peek
    Tree
    # Focus the editor when opening peek
    Editor
}

enum RenderLineHighlight {
    # Highlights both the gutter and the current line.
    All
}

enum RenderWhitespace {
    # Render whitespace characters except for single spaces between words.
    Boundary
    # Render whitespace characters only on selected text.
    Selection
    # Render only trailing whitespace characters.
    Trailing
}

enum ScrollbarHorizontal {
    # The horizontal scrollbar will be visible only when necessary.
    Auto
    # The horizontal scrollbar will always be visible.
    Visible
    # The horizontal scrollbar will always be hidden.
    Hidden
}

enum ScrollbarVertical {
    # The vertical scrollbar will be visible only when necessary.
    Auto
    # The vertical scrollbar will always be visible.
    Visible
    # The vertical scrollbar will always be hidden.
    Hidden
}

enum SemanticHighlightingEnabled {
    # Semantic highlighting enabled for all color themes.
    True
    # Semantic highlighting disabled for all color themes.
    False
    # Semantic highlighting is configured by the current color theme's `semanticHighlighting` setting.
    Configuredbytheme
}

enum ShowFoldingControls {
    # Always show the folding controls.
    Always
    # Never show the folding controls and reduce the gutter size.
    Never
    # Only show the folding controls when the mouse is over the gutter.
    Mouseover
}

enum SnippetSuggestions {
    # Show snippet suggestions on top of other suggestions.
    Top
    # Show snippet suggestions below other suggestions.
    Bottom
    # Show snippets suggestions with other suggestions.
    Inline
    # Do not show snippet suggestions.
    None
}

enum SuggestSelectionMode {
    # Always select a suggestion when automatically triggering IntelliSense.
    Always
    # Never select a suggestion when automatically triggering IntelliSense.
    Never
    # Select a suggestion only when triggering IntelliSense from a trigger character.
    Whentriggercharacter
    # Select a suggestion only when triggering IntelliSense as you type.
    Whenquicksuggestion
}

enum SuggestSelection {
    # Always select the first suggestion.
    First
    # Select recent suggestions unless further typing selects one, e.g. `console.| -> console.log` because `log` has been completed recently.
    Recentlyused
    # Select suggestions based on previous prefixes that have completed those suggestions, e.g. `co -> console` and `con -> const`.
    Recentlyusedbyprefix
}

enum TabCompletion {
    # Tab complete will insert the best matching suggestion when pressing tab.
    On
    # Disable tab completions.
    Off
    # Tab complete snippets when their prefix match. Works best when 'quickSuggestions' aren't enabled.
    Onlysnippets
}

enum UnusualLineTerminators {
    # Unusual line terminators are automatically removed.
    Auto
    # Unusual line terminators are ignored.
    Off
    # Unusual line terminators prompt to be removed.
    Prompt
}

enum WordBasedSuggestions {
    # Turn off Word Based Suggestions.
    Off
    # Only suggest words from the active document.
    Currentdocument
    # Suggest words from all open documents of the same language.
    Matchingdocuments
    # Suggest words from all open documents.
    Alldocuments
}

enum WordBreak {
    # Use the default line break rule.
    Normal
    # Word breaks should not be used for Chinese
    Keepall
}

enum WrappingIndent {
    # No indentation. Wrapped lines begin at column 1.
    None
    # Wrapped lines get the same indentation as the parent.
    Same
    # Wrapped lines get +1 indentation toward the parent.
    Indent
    # Wrapped lines get +2 indentation toward the parent.
    Deepindent
}

enum WrappingStrategy {
    # Assumes that all characters are of the same width. This is a fast algorithm that works correctly for monospace fonts and certain scripts (like Latin characters) where glyphs are of equal width.
    Simple
    # Delegates wrapping points computation to the browser. This is a slow algorithm, that might cause freezes for large files, but it works correctly in all cases.
    Advanced
}


[DscResource()]
class VSCodeEmmetSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $ExcludeLanguages

    [DscProperty()]
    [string] $ExtensionsPath

    [DscProperty()]
    [string] $IncludeLanguages

    [DscProperty()]
    [bool] $OptimizeStylesheetParsing

    [DscProperty()]
    [string] $Preferences

    [DscProperty()]
    [bool] $ShowAbbreviationSuggestions

    [DscProperty()]
    [string] $ShowExpandedAbbreviation

    [DscProperty()]
    [bool] $ShowSuggestionsAsSnippets

    [DscProperty()]
    [string] $SyntaxProfiles

    [DscProperty()]
    [bool] $TriggerExpansionOnTab

    [DscProperty()]
    [bool] $UseInlineCompletions

    [DscProperty()]
    [string] $Variables

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeEmmetSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeEmmetSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeEmmetSetting($settingsFile, $keys) {
        [VSCodeEmmetSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeEmmetSetting] Get() {
        $current = [VSCodeEmmetSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeEmmetSetting]::CurrentSettings

        }

        return [VSCodeEmmetSetting]@{
            ExcludeLanguages            = $this.ExcludeLanguages
            ExtensionsPath              = $this.ExtensionsPath
            IncludeLanguages            = $this.IncludeLanguages
            OptimizeStylesheetParsing   = $this.OptimizeStylesheetParsing
            Preferences                 = $this.Preferences
            ShowAbbreviationSuggestions = $this.ShowAbbreviationSuggestions
            ShowExpandedAbbreviation    = $this.ShowExpandedAbbreviation
            ShowSuggestionsAsSnippets   = $this.ShowSuggestionsAsSnippets
            SyntaxProfiles              = $this.SyntaxProfiles
            TriggerExpansionOnTab       = $this.TriggerExpansionOnTab
            UseInlineCompletions        = $this.UseInlineCompletions
            Variables                   = $this.Variables
            Exist                       = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeEmmetSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeEmmetSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeEmmetSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeEmmetSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeEmmetSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeEmmetSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeExtensionsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AutoCheckUpdates

    [DscProperty()]
    [bool] $AutoRestart

    [DscProperty()]
    [AutoUpdate] $AutoUpdate = [AutoUpdate]::True

    [DscProperty()]
    [bool] $CloseExtensionDetailsOnViewChange

    [DscProperty()]
    [string] $ConfirmedUriHandlerExtensionIds

    [DscProperty()]
    [bool] $IgnoreRecommendations

    [DscProperty()]
    [string] $SupportUntrustedWorkspaces

    [DscProperty()]
    [string] $SupportVirtualWorkspaces

    [DscProperty()]
    [bool] $VerifySignature

    [DscProperty()]
    [WebWorker] $WebWorker = [WebWorker]::Auto

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeExtensionsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeExtensionsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeExtensionsSetting($settingsFile, $keys) {
        [VSCodeExtensionsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeExtensionsSetting] Get() {
        $current = [VSCodeExtensionsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeExtensionsSetting]::CurrentSettings

        }

        return [VSCodeExtensionsSetting]@{
            AutoCheckUpdates                  = $this.AutoCheckUpdates
            AutoRestart                       = $this.AutoRestart
            AutoUpdate                        = $this.AutoUpdate
            CloseExtensionDetailsOnViewChange = $this.CloseExtensionDetailsOnViewChange
            ConfirmedUriHandlerExtensionIds   = $this.ConfirmedUriHandlerExtensionIds
            IgnoreRecommendations             = $this.IgnoreRecommendations
            SupportUntrustedWorkspaces        = $this.SupportUntrustedWorkspaces
            SupportVirtualWorkspaces          = $this.SupportVirtualWorkspaces
            VerifySignature                   = $this.VerifySignature
            WebWorker                         = $this.WebWorker
            Exist                             = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeExtensionsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeExtensionsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeExtensionsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeExtensionsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeExtensionsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeExtensionsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum AutoUpdate {
    # Download and install updates automatically for all extensions, except for those extensions where updates are ignored.
    True
    # Download and install updates automatically only for enabled extensions.
    Onlyenabledextensions
    # Extensions are not automatically updated.
    False
}

enum WebWorker {
    # The Web Worker Extension Host will always be launched.
    True
    # The Web Worker Extension Host will never be launched.
    False
    # The Web Worker Extension Host will be launched when a web extension needs it.
    Auto
}


[DscResource()]
class VSCodeFishSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Fish

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeFishSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeFishSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeFishSetting($settingsFile, $keys) {
        [VSCodeFishSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeFishSetting] Get() {
        $current = [VSCodeFishSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeFishSetting]::CurrentSettings

        }

        return [VSCodeFishSetting]@{
            Fish  = $this.Fish
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeFishSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeFishSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeFishSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeFishSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeFishSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeFishSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeGithubSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $BranchProtection

    [DscProperty()]
    [bool] $GitAuthentication

    [DscProperty()]
    [string] $GitProtocol

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeGithubSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeGithubSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeGithubSetting($settingsFile, $keys) {
        [VSCodeGithubSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeGithubSetting] Get() {
        $current = [VSCodeGithubSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeGithubSetting]::CurrentSettings

        }

        return [VSCodeGithubSetting]@{
            BranchProtection  = $this.BranchProtection
            GitAuthentication = $this.GitAuthentication
            GitProtocol       = $this.GitProtocol
            Exist             = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeGithubSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeGithubSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeGithubSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeGithubSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeGithubSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeGithubSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeGreenSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [int] $Green

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeGreenSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeGreenSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeGreenSetting($settingsFile, $keys) {
        [VSCodeGreenSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeGreenSetting] Get() {
        $current = [VSCodeGreenSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeGreenSetting]::CurrentSettings

        }

        return [VSCodeGreenSetting]@{
            Green = $this.Green
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeGreenSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeGreenSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeGreenSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeGreenSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeGreenSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeGreenSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeGruntSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $AutoDetect

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeGruntSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeGruntSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeGruntSetting($settingsFile, $keys) {
        [VSCodeGruntSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeGruntSetting] Get() {
        $current = [VSCodeGruntSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeGruntSetting]::CurrentSettings

        }

        return [VSCodeGruntSetting]@{
            AutoDetect = $this.AutoDetect
            Exist      = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeGruntSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeGruntSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeGruntSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeGruntSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeGruntSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeGruntSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeGulpSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $AutoDetect

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeGulpSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeGulpSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeGulpSetting($settingsFile, $keys) {
        [VSCodeGulpSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeGulpSetting] Get() {
        $current = [VSCodeGulpSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeGulpSetting]::CurrentSettings

        }

        return [VSCodeGulpSetting]@{
            AutoDetect = $this.AutoDetect
            Exist      = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeGulpSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeGulpSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeGulpSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeGulpSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeGulpSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeGulpSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeHttpSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $ElectronFetch

    [DscProperty()]
    [string] $NoProxy

    [DscProperty()]
    [string] $Proxy

    [DscProperty()]
    [string] $ProxyAuthorization

    [DscProperty()]
    [string] $ProxyKerberosServicePrincipal

    [DscProperty()]
    [bool] $ProxyStrictSSL

    [DscProperty()]
    [ProxySupport] $ProxySupport = [ProxySupport]::Override

    [DscProperty()]
    [bool] $SystemCertificates

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeHttpSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeHttpSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeHttpSetting($settingsFile, $keys) {
        [VSCodeHttpSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeHttpSetting] Get() {
        $current = [VSCodeHttpSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeHttpSetting]::CurrentSettings

        }

        return [VSCodeHttpSetting]@{
            ElectronFetch                 = $this.ElectronFetch
            NoProxy                       = $this.NoProxy
            Proxy                         = $this.Proxy
            ProxyAuthorization            = $this.ProxyAuthorization
            ProxyKerberosServicePrincipal = $this.ProxyKerberosServicePrincipal
            ProxyStrictSSL                = $this.ProxyStrictSSL
            ProxySupport                  = $this.ProxySupport
            SystemCertificates            = $this.SystemCertificates
            Exist                         = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeHttpSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeHttpSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeHttpSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeHttpSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeHttpSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeHttpSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum ProxySupport {
    # Disable proxy support for extensions.
    Off
    # Enable proxy support for extensions.
    On
    # Enable proxy support for extensions, fall back to request options, when no proxy found.
    Fallback
    # Enable proxy support for extensions, override request options.
    Override
}


[DscResource()]
class VSCodeIconSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Icon

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeIconSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeIconSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeIconSetting($settingsFile, $keys) {
        [VSCodeIconSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeIconSetting] Get() {
        $current = [VSCodeIconSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeIconSetting]::CurrentSettings

        }

        return [VSCodeIconSetting]@{
            Icon  = $this.Icon
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeIconSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeIconSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeIconSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeIconSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeIconSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeIconSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeImagePreviewSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $PreviewEditor

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeImagePreviewSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeImagePreviewSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeImagePreviewSetting($settingsFile, $keys) {
        [VSCodeImagePreviewSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeImagePreviewSetting] Get() {
        $current = [VSCodeImagePreviewSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeImagePreviewSetting]::CurrentSettings

        }

        return [VSCodeImagePreviewSetting]@{
            PreviewEditor = $this.PreviewEditor
            Exist         = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeImagePreviewSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeImagePreviewSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeImagePreviewSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeImagePreviewSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeImagePreviewSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeImagePreviewSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeInlineChatSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AcceptedOrDiscardBeforeSave

    [DscProperty()]
    [AccessibleDiffView] $AccessibleDiffView = [AccessibleDiffView]::Auto

    [DscProperty()]
    [bool] $FinishOnType

    [DscProperty()]
    [bool] $HoldToSpeech

    [DscProperty()]
    [Mode] $Mode = [Mode]::Live

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeInlineChatSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeInlineChatSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeInlineChatSetting($settingsFile, $keys) {
        [VSCodeInlineChatSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeInlineChatSetting] Get() {
        $current = [VSCodeInlineChatSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeInlineChatSetting]::CurrentSettings

        }

        return [VSCodeInlineChatSetting]@{
            AcceptedOrDiscardBeforeSave = $this.AcceptedOrDiscardBeforeSave
            AccessibleDiffView          = $this.AccessibleDiffView
            FinishOnType                = $this.FinishOnType
            HoldToSpeech                = $this.HoldToSpeech
            Mode                        = $this.Mode
            Exist                       = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeInlineChatSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeInlineChatSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeInlineChatSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeInlineChatSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeInlineChatSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeInlineChatSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum AccessibleDiffView {
    # The accessible diff viewer is based on screen reader mode being enabled.
    Auto
    # The accessible diff viewer is always enabled.
    On
    # The accessible diff viewer is never enabled.
    Off
}

enum Mode {
    # Changes are applied directly to the document, can be highlighted via inline diffs, and accepted
    Live
    # Changes are previewed only and need to be accepted via the apply button. Ending a session will discard the changes.
    Preview
}


[DscResource()]
class VSCodeInteractiveWindowSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AlwaysScrollOnNewCell

    [DscProperty()]
    [string] $CollapseCellInputCode

    [DscProperty()]
    [bool] $ExecuteWithShiftEnter

    [DscProperty()]
    [bool] $PromptToSaveOnClose

    [DscProperty()]
    [bool] $ShowExecutionHint

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeInteractiveWindowSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeInteractiveWindowSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeInteractiveWindowSetting($settingsFile, $keys) {
        [VSCodeInteractiveWindowSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeInteractiveWindowSetting] Get() {
        $current = [VSCodeInteractiveWindowSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeInteractiveWindowSetting]::CurrentSettings

        }

        return [VSCodeInteractiveWindowSetting]@{
            AlwaysScrollOnNewCell = $this.AlwaysScrollOnNewCell
            CollapseCellInputCode = $this.CollapseCellInputCode
            ExecuteWithShiftEnter = $this.ExecuteWithShiftEnter
            PromptToSaveOnClose   = $this.PromptToSaveOnClose
            ShowExecutionHint     = $this.ShowExecutionHint
            Exist                 = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeInteractiveWindowSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeInteractiveWindowSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeInteractiveWindowSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeInteractiveWindowSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeInteractiveWindowSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeInteractiveWindowSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeIpynbSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $PasteImagesAsAttachmentsEnabled

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeIpynbSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeIpynbSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeIpynbSetting($settingsFile, $keys) {
        [VSCodeIpynbSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeIpynbSetting] Get() {
        $current = [VSCodeIpynbSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeIpynbSetting]::CurrentSettings

        }

        return [VSCodeIpynbSetting]@{
            PasteImagesAsAttachmentsEnabled = $this.PasteImagesAsAttachmentsEnabled
            Exist                           = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeIpynbSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeIpynbSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeIpynbSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeIpynbSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeIpynbSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeIpynbSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeJakeSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $AutoDetect

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeJakeSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeJakeSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeJakeSetting($settingsFile, $keys) {
        [VSCodeJakeSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeJakeSetting] Get() {
        $current = [VSCodeJakeSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeJakeSetting]::CurrentSettings

        }

        return [VSCodeJakeSetting]@{
            AutoDetect = $this.AutoDetect
            Exist      = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeJakeSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeJakeSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeJakeSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeJakeSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeJakeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeJakeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeJsonSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $FormatEnable

    [DscProperty()]
    [bool] $FormatKeepLines

    [DscProperty()]
    [int] $MaxItemsComputed

    [DscProperty()]
    [bool] $SchemaDownloadEnable

    [DscProperty()]
    [string] $Schemas

    [DscProperty()]
    [string] $TraceServer

    [DscProperty()]
    [bool] $ValidateEnable

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeJsonSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeJsonSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeJsonSetting($settingsFile, $keys) {
        [VSCodeJsonSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeJsonSetting] Get() {
        $current = [VSCodeJsonSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeJsonSetting]::CurrentSettings

        }

        return [VSCodeJsonSetting]@{
            FormatEnable         = $this.FormatEnable
            FormatKeepLines      = $this.FormatKeepLines
            MaxItemsComputed     = $this.MaxItemsComputed
            SchemaDownloadEnable = $this.SchemaDownloadEnable
            Schemas              = $this.Schemas
            TraceServer          = $this.TraceServer
            ValidateEnable       = $this.ValidateEnable
            Exist                = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeJsonSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeJsonSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeJsonSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeJsonSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeJsonSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeJsonSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeJsProfileVisualizerSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CpuprofileTable

    [DscProperty()]
    [bool] $HeapprofileTable

    [DscProperty()]
    [bool] $HeapsnapshotTable

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeJsProfileVisualizerSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeJsProfileVisualizerSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeJsProfileVisualizerSetting($settingsFile, $keys) {
        [VSCodeJsProfileVisualizerSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeJsProfileVisualizerSetting] Get() {
        $current = [VSCodeJsProfileVisualizerSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeJsProfileVisualizerSetting]::CurrentSettings

        }

        return [VSCodeJsProfileVisualizerSetting]@{
            CpuprofileTable   = $this.CpuprofileTable
            HeapprofileTable  = $this.HeapprofileTable
            HeapsnapshotTable = $this.HeapsnapshotTable
            Exist             = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeJsProfileVisualizerSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeJsProfileVisualizerSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeJsProfileVisualizerSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeJsProfileVisualizerSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeJsProfileVisualizerSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeJsProfileVisualizerSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeKeyboardSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Dispatch

    [DscProperty()]
    [bool] $MapAltGrToCtrlAlt

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeKeyboardSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeKeyboardSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeKeyboardSetting($settingsFile, $keys) {
        [VSCodeKeyboardSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeKeyboardSetting] Get() {
        $current = [VSCodeKeyboardSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeKeyboardSetting]::CurrentSettings

        }

        return [VSCodeKeyboardSetting]@{
            Dispatch          = $this.Dispatch
            MapAltGrToCtrlAlt = $this.MapAltGrToCtrlAlt
            Exist             = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeKeyboardSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeKeyboardSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeKeyboardSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeKeyboardSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeKeyboardSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeKeyboardSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeLaunchSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Launch

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeLaunchSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeLaunchSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeLaunchSetting($settingsFile, $keys) {
        [VSCodeLaunchSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeLaunchSetting] Get() {
        $current = [VSCodeLaunchSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeLaunchSetting]::CurrentSettings

        }

        return [VSCodeLaunchSetting]@{
            Launch = $this.Launch
            Exist  = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeLaunchSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeLaunchSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeLaunchSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeLaunchSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeLaunchSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeLaunchSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeLessSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CompletionCompletePropertyWithSemicolon

    [DscProperty()]
    [bool] $CompletionTriggerPropertyValueCompletion

    [DscProperty()]
    [string] $FormatBraceStyle

    [DscProperty()]
    [bool] $FormatEnable

    [DscProperty()]
    [string] $FormatMaxPreserveNewLines

    [DscProperty()]
    [bool] $FormatNewlineBetweenRules

    [DscProperty()]
    [bool] $FormatNewlineBetweenSelectors

    [DscProperty()]
    [bool] $FormatPreserveNewLines

    [DscProperty()]
    [bool] $FormatSpaceAroundSelectorSeparator

    [DscProperty()]
    [bool] $HoverDocumentation

    [DscProperty()]
    [bool] $HoverReferences

    [DscProperty()]
    [string] $LintArgumentsInColorFunction

    [DscProperty()]
    [string] $LintBoxModel

    [DscProperty()]
    [string] $LintCompatibleVendorPrefixes

    [DscProperty()]
    [string] $LintDuplicateProperties

    [DscProperty()]
    [string] $LintEmptyRules

    [DscProperty()]
    [string] $LintFloat

    [DscProperty()]
    [string] $LintFontFaceProperties

    [DscProperty()]
    [string] $LintHexColorLength

    [DscProperty()]
    [string] $LintIdSelector

    [DscProperty()]
    [string] $LintIeHack

    [DscProperty()]
    [string] $LintImportant

    [DscProperty()]
    [string] $LintImportStatement

    [DscProperty()]
    [string] $LintPropertyIgnoredDueToDisplay

    [DscProperty()]
    [string] $LintUniversalSelector

    [DscProperty()]
    [string] $LintUnknownAtRules

    [DscProperty()]
    [string] $LintUnknownProperties

    [DscProperty()]
    [string] $LintUnknownVendorSpecificProperties

    [DscProperty()]
    [string] $LintValidProperties

    [DscProperty()]
    [string] $LintVendorPrefix

    [DscProperty()]
    [string] $LintZeroUnits

    [DscProperty()]
    [bool] $Validate

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeLessSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeLessSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeLessSetting($settingsFile, $keys) {
        [VSCodeLessSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeLessSetting] Get() {
        $current = [VSCodeLessSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeLessSetting]::CurrentSettings

        }

        return [VSCodeLessSetting]@{
            CompletionCompletePropertyWithSemicolon  = $this.CompletionCompletePropertyWithSemicolon
            CompletionTriggerPropertyValueCompletion = $this.CompletionTriggerPropertyValueCompletion
            FormatBraceStyle                         = $this.FormatBraceStyle
            FormatEnable                             = $this.FormatEnable
            FormatMaxPreserveNewLines                = $this.FormatMaxPreserveNewLines
            FormatNewlineBetweenRules                = $this.FormatNewlineBetweenRules
            FormatNewlineBetweenSelectors            = $this.FormatNewlineBetweenSelectors
            FormatPreserveNewLines                   = $this.FormatPreserveNewLines
            FormatSpaceAroundSelectorSeparator       = $this.FormatSpaceAroundSelectorSeparator
            HoverDocumentation                       = $this.HoverDocumentation
            HoverReferences                          = $this.HoverReferences
            LintArgumentsInColorFunction             = $this.LintArgumentsInColorFunction
            LintBoxModel                             = $this.LintBoxModel
            LintCompatibleVendorPrefixes             = $this.LintCompatibleVendorPrefixes
            LintDuplicateProperties                  = $this.LintDuplicateProperties
            LintEmptyRules                           = $this.LintEmptyRules
            LintFloat                                = $this.LintFloat
            LintFontFaceProperties                   = $this.LintFontFaceProperties
            LintHexColorLength                       = $this.LintHexColorLength
            LintIdSelector                           = $this.LintIdSelector
            LintIeHack                               = $this.LintIeHack
            LintImportant                            = $this.LintImportant
            LintImportStatement                      = $this.LintImportStatement
            LintPropertyIgnoredDueToDisplay          = $this.LintPropertyIgnoredDueToDisplay
            LintUniversalSelector                    = $this.LintUniversalSelector
            LintUnknownAtRules                       = $this.LintUnknownAtRules
            LintUnknownProperties                    = $this.LintUnknownProperties
            LintUnknownVendorSpecificProperties      = $this.LintUnknownVendorSpecificProperties
            LintValidProperties                      = $this.LintValidProperties
            LintVendorPrefix                         = $this.LintVendorPrefix
            LintZeroUnits                            = $this.LintZeroUnits
            Validate                                 = $this.Validate
            Exist                                    = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeLessSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeLessSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeLessSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeLessSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeLessSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeLessSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeMarkdownSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $CopyFilesDestination

    [DscProperty()]
    [CopyFilesOverwriteBehavior] $CopyFilesOverwriteBehavior = [CopyFilesOverwriteBehavior]::Nameincrementally

    [DscProperty()]
    [EditorDropCopyIntoWorkspace] $EditorDropCopyIntoWorkspace = [EditorDropCopyIntoWorkspace]::Mediafiles

    [DscProperty()]
    [EditorDropEnabled] $EditorDropEnabled = [EditorDropEnabled]::Smart

    [DscProperty()]
    [string] $EditorFilePasteAudioSnippet

    [DscProperty()]
    [EditorFilePasteCopyIntoWorkspace] $EditorFilePasteCopyIntoWorkspace = [EditorFilePasteCopyIntoWorkspace]::Mediafiles

    [DscProperty()]
    [EditorFilePasteEnabled] $EditorFilePasteEnabled = [EditorFilePasteEnabled]::Smart

    [DscProperty()]
    [string] $EditorFilePasteVideoSnippet

    [DscProperty()]
    [EditorPasteUrlAsFormattedLinkEnabled] $EditorPasteUrlAsFormattedLinkEnabled = [EditorPasteUrlAsFormattedLinkEnabled]::Smartwithselection

    [DscProperty()]
    [bool] $EditorUpdateLinksOnPasteEnabled

    [DscProperty()]
    [LinksOpenLocation] $LinksOpenLocation = [LinksOpenLocation]::Currentgroup

    [DscProperty()]
    [bool] $MathEnabled

    [DscProperty()]
    [string] $MathMacros

    [DscProperty()]
    [bool] $OccurrencesHighlightEnabled

    [DscProperty()]
    [PreferredMdPathExtensionStyle] $PreferredMdPathExtensionStyle = [PreferredMdPathExtensionStyle]::Auto

    [DscProperty()]
    [bool] $PreviewBreaks

    [DscProperty()]
    [bool] $PreviewDoubleClickToSwitchToEditor

    [DscProperty()]
    [string] $PreviewFontFamily

    [DscProperty()]
    [int] $PreviewFontSize

    [DscProperty()]
    [double] $PreviewLineHeight

    [DscProperty()]
    [bool] $PreviewLinkify

    [DscProperty()]
    [bool] $PreviewMarkEditorSelection

    [DscProperty()]
    [PreviewOpenMarkdownLinks] $PreviewOpenMarkdownLinks = [PreviewOpenMarkdownLinks]::Inpreview

    [DscProperty()]
    [bool] $PreviewScrollEditorWithPreview

    [DscProperty()]
    [bool] $PreviewScrollPreviewWithEditor

    [DscProperty()]
    [bool] $PreviewTypographer

    [DscProperty()]
    [string] $ServerLog

    [DscProperty()]
    [string] $Styles

    [DscProperty()]
    [bool] $SuggestPathsEnabled

    [DscProperty()]
    [SuggestPathsIncludeWorkspaceHeaderCompletions] $SuggestPathsIncludeWorkspaceHeaderCompletions = [SuggestPathsIncludeWorkspaceHeaderCompletions]::Ondoublehash

    [DscProperty()]
    [string] $TraceExtension

    [DscProperty()]
    [string] $TraceServer

    [DscProperty()]
    [UpdateLinksOnFileMoveEnabled] $UpdateLinksOnFileMoveEnabled = [UpdateLinksOnFileMoveEnabled]::Never

    [DscProperty()]
    [bool] $UpdateLinksOnFileMoveEnableForDirectories

    [DscProperty()]
    [string] $UpdateLinksOnFileMoveInclude

    [DscProperty()]
    [string] $ValidateDuplicateLinkDefinitionsEnabled

    [DscProperty()]
    [bool] $ValidateEnabled

    [DscProperty()]
    [string] $ValidateFileLinksEnabled

    [DscProperty()]
    [string] $ValidateFileLinksMarkdownFragmentLinks

    [DscProperty()]
    [string] $ValidateFragmentLinksEnabled

    [DscProperty()]
    [string] $ValidateIgnoredLinks

    [DscProperty()]
    [string] $ValidateReferenceLinksEnabled

    [DscProperty()]
    [string] $ValidateUnusedLinkDefinitionsEnabled

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeMarkdownSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeMarkdownSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeMarkdownSetting($settingsFile, $keys) {
        [VSCodeMarkdownSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeMarkdownSetting] Get() {
        $current = [VSCodeMarkdownSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeMarkdownSetting]::CurrentSettings

        }

        return [VSCodeMarkdownSetting]@{
            CopyFilesDestination                          = $this.CopyFilesDestination
            CopyFilesOverwriteBehavior                    = $this.CopyFilesOverwriteBehavior
            EditorDropCopyIntoWorkspace                   = $this.EditorDropCopyIntoWorkspace
            EditorDropEnabled                             = $this.EditorDropEnabled
            EditorFilePasteAudioSnippet                   = $this.EditorFilePasteAudioSnippet
            EditorFilePasteCopyIntoWorkspace              = $this.EditorFilePasteCopyIntoWorkspace
            EditorFilePasteEnabled                        = $this.EditorFilePasteEnabled
            EditorFilePasteVideoSnippet                   = $this.EditorFilePasteVideoSnippet
            EditorPasteUrlAsFormattedLinkEnabled          = $this.EditorPasteUrlAsFormattedLinkEnabled
            EditorUpdateLinksOnPasteEnabled               = $this.EditorUpdateLinksOnPasteEnabled
            LinksOpenLocation                             = $this.LinksOpenLocation
            MathEnabled                                   = $this.MathEnabled
            MathMacros                                    = $this.MathMacros
            OccurrencesHighlightEnabled                   = $this.OccurrencesHighlightEnabled
            PreferredMdPathExtensionStyle                 = $this.PreferredMdPathExtensionStyle
            PreviewBreaks                                 = $this.PreviewBreaks
            PreviewDoubleClickToSwitchToEditor            = $this.PreviewDoubleClickToSwitchToEditor
            PreviewFontFamily                             = $this.PreviewFontFamily
            PreviewFontSize                               = $this.PreviewFontSize
            PreviewLineHeight                             = $this.PreviewLineHeight
            PreviewLinkify                                = $this.PreviewLinkify
            PreviewMarkEditorSelection                    = $this.PreviewMarkEditorSelection
            PreviewOpenMarkdownLinks                      = $this.PreviewOpenMarkdownLinks
            PreviewScrollEditorWithPreview                = $this.PreviewScrollEditorWithPreview
            PreviewScrollPreviewWithEditor                = $this.PreviewScrollPreviewWithEditor
            PreviewTypographer                            = $this.PreviewTypographer
            ServerLog                                     = $this.ServerLog
            Styles                                        = $this.Styles
            SuggestPathsEnabled                           = $this.SuggestPathsEnabled
            SuggestPathsIncludeWorkspaceHeaderCompletions = $this.SuggestPathsIncludeWorkspaceHeaderCompletions
            TraceExtension                                = $this.TraceExtension
            TraceServer                                   = $this.TraceServer
            UpdateLinksOnFileMoveEnabled                  = $this.UpdateLinksOnFileMoveEnabled
            UpdateLinksOnFileMoveEnableForDirectories     = $this.UpdateLinksOnFileMoveEnableForDirectories
            UpdateLinksOnFileMoveInclude                  = $this.UpdateLinksOnFileMoveInclude
            ValidateDuplicateLinkDefinitionsEnabled       = $this.ValidateDuplicateLinkDefinitionsEnabled
            ValidateEnabled                               = $this.ValidateEnabled
            ValidateFileLinksEnabled                      = $this.ValidateFileLinksEnabled
            ValidateFileLinksMarkdownFragmentLinks        = $this.ValidateFileLinksMarkdownFragmentLinks
            ValidateFragmentLinksEnabled                  = $this.ValidateFragmentLinksEnabled
            ValidateIgnoredLinks                          = $this.ValidateIgnoredLinks
            ValidateReferenceLinksEnabled                 = $this.ValidateReferenceLinksEnabled
            ValidateUnusedLinkDefinitionsEnabled          = $this.ValidateUnusedLinkDefinitionsEnabled
            Exist                                         = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeMarkdownSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeMarkdownSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeMarkdownSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeMarkdownSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMarkdownSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMarkdownSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum CopyFilesOverwriteBehavior {
    # If a file with the same name already exists, append a number to the file name, for example: `image.png` becomes `image-1.png`.
    Nameincrementally
    # If a file with the same name already exists, overwrite it.
    Overwrite
}

enum EditorDropCopyIntoWorkspace {
    # Try to copy external image and video files into the workspace.
    Mediafiles
    # Do not copy external files into the workspace.
    Never
}

enum EditorDropEnabled {
    # Always insert Markdown links.
    Always
    # Smartly create Markdown links by default when not dropping into a code block or other special element. Use the drop widget to switch between pasting as plain text or as Markdown links.
    Smart
    # Never create Markdown links.
    Never
}

enum EditorFilePasteCopyIntoWorkspace {
    # Try to copy external image and video files into the workspace.
    Mediafiles
    # Do not copy external files into the workspace.
    Never
}

enum EditorFilePasteEnabled {
    # Always insert Markdown links.
    Always
    # Smartly create Markdown links by default when not pasting into a code block or other special element. Use the paste widget to switch between pasting as plain text or as Markdown links.
    Smart
    # Never create Markdown links.
    Never
}

enum EditorPasteUrlAsFormattedLinkEnabled {
    # Always insert Markdown links.
    Always
    # Smartly create Markdown links by default when not pasting into a code block or other special element. Use the paste widget to switch between pasting as plain text or as Markdown links.
    Smart
    # Smartly create Markdown links by default when you have selected text and are not pasting into a code block or other special element. Use the paste widget to switch between pasting as plain text or as Markdown links.
    Smartwithselection
    # Never create Markdown links.
    Never
}

enum LinksOpenLocation {
    # Open links in the active editor group.
    Currentgroup
    # Open links beside the active editor.
    Beside
}

enum PreferredMdPathExtensionStyle {
    # For existing paths, try to maintain the file extension style. For new paths, add file extensions.
    Auto
    # Prefer including the file extension. For example, path completions to a file named `file.md` will insert `file.md`.
    Includeextension
    # Prefer removing the file extension. For example, path completions to a file named `file.md` will insert `file` without the `.md`.
    Removeextension
}

enum PreviewOpenMarkdownLinks {
    # Try to open links in the Markdown preview.
    Inpreview
    # Try to open links in the editor.
    Ineditor
}

enum SuggestPathsIncludeWorkspaceHeaderCompletions {
    # Disable workspace header suggestions.
    Never
    # Enable workspace header suggestions after typing `#` in a path, for example: `[link text](#`.
    Ondoublehash
    # Enable workspace header suggestions after typing either `#` or `#` in a path, for example: `[link text](#` or `[link text](#`.
    Onsingleordoublehash
}

enum UpdateLinksOnFileMoveEnabled {
    # Prompt on each file move.
    Prompt
    # Always update links automatically.
    Always
    # Never try to update link and don't prompt.
    Never
}


[DscResource()]
class VSCodeMarkupPreviewSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $MarkupPreview

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeMarkupPreviewSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeMarkupPreviewSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeMarkupPreviewSetting($settingsFile, $keys) {
        [VSCodeMarkupPreviewSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeMarkupPreviewSetting] Get() {
        $current = [VSCodeMarkupPreviewSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeMarkupPreviewSetting]::CurrentSettings

        }

        return [VSCodeMarkupPreviewSetting]@{
            MarkupPreview = $this.MarkupPreview
            Exist         = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeMarkupPreviewSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeMarkupPreviewSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeMarkupPreviewSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeMarkupPreviewSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMarkupPreviewSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMarkupPreviewSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeMarkupSourceSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $MarkupSource

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeMarkupSourceSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeMarkupSourceSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeMarkupSourceSetting($settingsFile, $keys) {
        [VSCodeMarkupSourceSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeMarkupSourceSetting] Get() {
        $current = [VSCodeMarkupSourceSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeMarkupSourceSetting]::CurrentSettings

        }

        return [VSCodeMarkupSourceSetting]@{
            MarkupSource = $this.MarkupSource
            Exist        = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeMarkupSourceSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeMarkupSourceSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeMarkupSourceSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeMarkupSourceSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMarkupSourceSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMarkupSourceSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeMediaPreviewSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $VideoAutoPlay

    [DscProperty()]
    [bool] $VideoLoop

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeMediaPreviewSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeMediaPreviewSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeMediaPreviewSetting($settingsFile, $keys) {
        [VSCodeMediaPreviewSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeMediaPreviewSetting] Get() {
        $current = [VSCodeMediaPreviewSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeMediaPreviewSetting]::CurrentSettings

        }

        return [VSCodeMediaPreviewSetting]@{
            VideoAutoPlay = $this.VideoAutoPlay
            VideoLoop     = $this.VideoLoop
            Exist         = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeMediaPreviewSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeMediaPreviewSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeMediaPreviewSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeMediaPreviewSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMediaPreviewSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMediaPreviewSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeMergeEditorSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [DiffAlgorithm] $DiffAlgorithm = [DiffAlgorithm]::Advanced

    [DscProperty()]
    [bool] $ShowDeletionMarkers

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeMergeEditorSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeMergeEditorSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeMergeEditorSetting($settingsFile, $keys) {
        [VSCodeMergeEditorSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeMergeEditorSetting] Get() {
        $current = [VSCodeMergeEditorSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeMergeEditorSetting]::CurrentSettings

        }

        return [VSCodeMergeEditorSetting]@{
            DiffAlgorithm       = $this.DiffAlgorithm
            ShowDeletionMarkers = $this.ShowDeletionMarkers
            Exist               = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeMergeEditorSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeMergeEditorSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeMergeEditorSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeMergeEditorSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMergeEditorSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMergeEditorSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeMicrosoftSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $UseMsal

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeMicrosoftSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeMicrosoftSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeMicrosoftSetting($settingsFile, $keys) {
        [VSCodeMicrosoftSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeMicrosoftSetting] Get() {
        $current = [VSCodeMicrosoftSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeMicrosoftSetting]::CurrentSettings

        }

        return [VSCodeMicrosoftSetting]@{
            UseMsal = $this.UseMsal
            Exist   = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeMicrosoftSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeMicrosoftSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeMicrosoftSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeMicrosoftSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMicrosoftSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeMicrosoftSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeModifiedSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $Modified

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeModifiedSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeModifiedSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeModifiedSetting($settingsFile, $keys) {
        [VSCodeModifiedSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeModifiedSetting] Get() {
        $current = [VSCodeModifiedSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeModifiedSetting]::CurrentSettings

        }

        return [VSCodeModifiedSetting]@{
            Modified = $this.Modified
            Exist    = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeModifiedSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeModifiedSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeModifiedSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeModifiedSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeModifiedSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeModifiedSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeNotebookSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [int] $BackupSizeLimit

    [DscProperty()]
    [bool] $BreadcrumbsShowCodeCells

    [DscProperty()]
    [bool] $CellFailureDiagnostics

    [DscProperty()]
    [string] $CellFocusIndicator

    [DscProperty()]
    [string] $CellToolbarLocation

    [DscProperty()]
    [string] $CellToolbarVisibility

    [DscProperty()]
    [string] $CodeActionsOnSave

    [DscProperty()]
    [bool] $CompactView

    [DscProperty()]
    [bool] $ConfirmDeleteRunningCell

    [DscProperty()]
    [bool] $ConsolidatedOutputButton

    [DscProperty()]
    [bool] $ConsolidatedRunButton

    [DscProperty()]
    [string] $DefaultFormatter

    [DscProperty()]
    [bool] $DiffEnablePreview

    [DscProperty()]
    [bool] $DiffIgnoreMetadata

    [DscProperty()]
    [bool] $DiffIgnoreOutputs

    [DscProperty()]
    [bool] $DiffOverviewRuler

    [DscProperty()]
    [string] $DisplayOrder

    [DscProperty()]
    [bool] $DragAndDropEnabled

    [DscProperty()]
    [string] $EditorOptionsCustomizations

    [DscProperty()]
    [string] $FindFilters

    [DscProperty()]
    [bool] $FormatOnCellExecution

    [DscProperty()]
    [bool] $FormatOnSaveEnabled

    [DscProperty()]
    [bool] $GlobalToolbar

    [DscProperty()]
    [string] $GlobalToolbarShowLabel

    [DscProperty()]
    [bool] $GotoSymbolsShowAllSymbols

    [DscProperty()]
    [bool] $InsertFinalNewline

    [DscProperty()]
    [InsertToolbarLocation] $InsertToolbarLocation = [InsertToolbarLocation]::Both

    [DscProperty()]
    [string] $LineNumbers

    [DscProperty()]
    [int] $MarkdownLineHeight

    [DscProperty()]
    [int] $MarkupFontSize

    [DscProperty()]
    [bool] $NavigationAllowNavigateToSurroundingCells

    [DscProperty()]
    [bool] $OutlineShowCodeCells

    [DscProperty()]
    [bool] $OutlineShowCodeCellSymbols

    [DscProperty()]
    [bool] $OutlineShowMarkdownHeadersOnly

    [DscProperty()]
    [string] $OutputFontFamily

    [DscProperty()]
    [int] $OutputFontSize

    [DscProperty()]
    [int] $OutputLineHeight

    [DscProperty()]
    [bool] $OutputLinkifyFilePaths

    [DscProperty()]
    [bool] $OutputMinimalErrorRendering

    [DscProperty()]
    [bool] $OutputScrolling

    [DscProperty()]
    [int] $OutputTextLineLimit

    [DscProperty()]
    [bool] $OutputWordWrap

    [DscProperty()]
    [ScrollingRevealNextCellOnExecute] $ScrollingRevealNextCellOnExecute = [ScrollingRevealNextCellOnExecute]::Fullcell

    [DscProperty()]
    [ShowCellStatusBar] $ShowCellStatusBar = [ShowCellStatusBar]::Visible

    [DscProperty()]
    [ShowFoldingControls] $ShowFoldingControls = [ShowFoldingControls]::Mouseover

    [DscProperty()]
    [bool] $StickyScrollEnabled

    [DscProperty()]
    [StickyScrollMode] $StickyScrollMode = [StickyScrollMode]::Indented

    [DscProperty()]
    [bool] $UndoRedoPerCell

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeNotebookSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeNotebookSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeNotebookSetting($settingsFile, $keys) {
        [VSCodeNotebookSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeNotebookSetting] Get() {
        $current = [VSCodeNotebookSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeNotebookSetting]::CurrentSettings

        }

        return [VSCodeNotebookSetting]@{
            BackupSizeLimit                           = $this.BackupSizeLimit
            BreadcrumbsShowCodeCells                  = $this.BreadcrumbsShowCodeCells
            CellFailureDiagnostics                    = $this.CellFailureDiagnostics
            CellFocusIndicator                        = $this.CellFocusIndicator
            CellToolbarLocation                       = $this.CellToolbarLocation
            CellToolbarVisibility                     = $this.CellToolbarVisibility
            CodeActionsOnSave                         = $this.CodeActionsOnSave
            CompactView                               = $this.CompactView
            ConfirmDeleteRunningCell                  = $this.ConfirmDeleteRunningCell
            ConsolidatedOutputButton                  = $this.ConsolidatedOutputButton
            ConsolidatedRunButton                     = $this.ConsolidatedRunButton
            DefaultFormatter                          = $this.DefaultFormatter
            DiffEnablePreview                         = $this.DiffEnablePreview
            DiffIgnoreMetadata                        = $this.DiffIgnoreMetadata
            DiffIgnoreOutputs                         = $this.DiffIgnoreOutputs
            DiffOverviewRuler                         = $this.DiffOverviewRuler
            DisplayOrder                              = $this.DisplayOrder
            DragAndDropEnabled                        = $this.DragAndDropEnabled
            EditorOptionsCustomizations               = $this.EditorOptionsCustomizations
            FindFilters                               = $this.FindFilters
            FormatOnCellExecution                     = $this.FormatOnCellExecution
            FormatOnSaveEnabled                       = $this.FormatOnSaveEnabled
            GlobalToolbar                             = $this.GlobalToolbar
            GlobalToolbarShowLabel                    = $this.GlobalToolbarShowLabel
            GotoSymbolsShowAllSymbols                 = $this.GotoSymbolsShowAllSymbols
            InsertFinalNewline                        = $this.InsertFinalNewline
            InsertToolbarLocation                     = $this.InsertToolbarLocation
            LineNumbers                               = $this.LineNumbers
            MarkdownLineHeight                        = $this.MarkdownLineHeight
            MarkupFontSize                            = $this.MarkupFontSize
            NavigationAllowNavigateToSurroundingCells = $this.NavigationAllowNavigateToSurroundingCells
            OutlineShowCodeCells                      = $this.OutlineShowCodeCells
            OutlineShowCodeCellSymbols                = $this.OutlineShowCodeCellSymbols
            OutlineShowMarkdownHeadersOnly            = $this.OutlineShowMarkdownHeadersOnly
            OutputFontFamily                          = $this.OutputFontFamily
            OutputFontSize                            = $this.OutputFontSize
            OutputLineHeight                          = $this.OutputLineHeight
            OutputLinkifyFilePaths                    = $this.OutputLinkifyFilePaths
            OutputMinimalErrorRendering               = $this.OutputMinimalErrorRendering
            OutputScrolling                           = $this.OutputScrolling
            OutputTextLineLimit                       = $this.OutputTextLineLimit
            OutputWordWrap                            = $this.OutputWordWrap
            ScrollingRevealNextCellOnExecute          = $this.ScrollingRevealNextCellOnExecute
            ShowCellStatusBar                         = $this.ShowCellStatusBar
            ShowFoldingControls                       = $this.ShowFoldingControls
            StickyScrollEnabled                       = $this.StickyScrollEnabled
            StickyScrollMode                          = $this.StickyScrollMode
            UndoRedoPerCell                           = $this.UndoRedoPerCell
            Exist                                     = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeNotebookSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeNotebookSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeNotebookSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeNotebookSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeNotebookSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeNotebookSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum InsertToolbarLocation {
    # A toolbar that appears on hover between cells.
    Betweencells
    # The toolbar at the top of the notebook editor.
    Notebooktoolbar
    # Both toolbars.
    Both
    # The insert actions don't appear anywhere.
    Hidden
}

enum ScrollingRevealNextCellOnExecute {
    # Scroll to fully reveal the next cell.
    Fullcell
    # Scroll to reveal the first line of the next cell.
    Firstline
    # Do not scroll.
    None
}

enum ShowCellStatusBar {
    # The cell Status bar is always hidden.
    Hidden
    # The cell Status bar is always visible.
    Visible
    # The cell Status bar is hidden until the cell has executed. Then it becomes visible to show the execution status.
    Visibleafterexecute
}

enum StickyScrollMode {
    # Nested sticky lines appear flat.
    Flat
    # Nested sticky lines appear indented.
    Indented
}


[DscResource()]
class VSCodeNotebookEditorsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $NotebookEditors

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeNotebookEditorsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeNotebookEditorsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeNotebookEditorsSetting($settingsFile, $keys) {
        [VSCodeNotebookEditorsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeNotebookEditorsSetting] Get() {
        $current = [VSCodeNotebookEditorsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeNotebookEditorsSetting]::CurrentSettings

        }

        return [VSCodeNotebookEditorsSetting]@{
            NotebookEditors = $this.NotebookEditors
            Exist           = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeNotebookEditorsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeNotebookEditorsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeNotebookEditorsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeNotebookEditorsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeNotebookEditorsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeNotebookEditorsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeNpmSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $AutoDetect

    [DscProperty()]
    [bool] $EnableRunFromFolder

    [DscProperty()]
    [bool] $EnableScriptExplorer

    [DscProperty()]
    [string] $Exclude

    [DscProperty()]
    [bool] $FetchOnlinePackageInfo

    [DscProperty()]
    [PackageManager] $PackageManager = [PackageManager]::Auto

    [DscProperty()]
    [bool] $RunSilent

    [DscProperty()]
    [string] $ScriptExplorerAction

    [DscProperty()]
    [string] $ScriptExplorerExclude

    [DscProperty()]
    [bool] $ScriptHover

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeNpmSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeNpmSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeNpmSetting($settingsFile, $keys) {
        [VSCodeNpmSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeNpmSetting] Get() {
        $current = [VSCodeNpmSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeNpmSetting]::CurrentSettings

        }

        return [VSCodeNpmSetting]@{
            AutoDetect             = $this.AutoDetect
            EnableRunFromFolder    = $this.EnableRunFromFolder
            EnableScriptExplorer   = $this.EnableScriptExplorer
            Exclude                = $this.Exclude
            FetchOnlinePackageInfo = $this.FetchOnlinePackageInfo
            PackageManager         = $this.PackageManager
            RunSilent              = $this.RunSilent
            ScriptExplorerAction   = $this.ScriptExplorerAction
            ScriptExplorerExclude  = $this.ScriptExplorerExclude
            ScriptHover            = $this.ScriptHover
            Exist                  = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeNpmSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeNpmSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeNpmSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeNpmSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeNpmSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeNpmSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum PackageManager {
    # Auto-detect which package manager to use for running scripts based on lock files and installed package managers.
    Auto
    # Use npm as the package manager for running scripts.
    Npm
    # Use yarn as the package manager for running scripts.
    Yarn
    # Use pnpm as the package manager for running scripts.
    Pnpm
    # Use bun as the package manager for running scripts.
    Bun
}


[DscResource()]
class VSCodeOtherSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Other

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeOtherSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeOtherSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeOtherSetting($settingsFile, $keys) {
        [VSCodeOtherSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeOtherSetting] Get() {
        $current = [VSCodeOtherSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeOtherSetting]::CurrentSettings

        }

        return [VSCodeOtherSetting]@{
            Other = $this.Other
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeOtherSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeOtherSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeOtherSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeOtherSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeOtherSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeOtherSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeOutlineSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [CollapseItems] $CollapseItems = [CollapseItems]::Alwaysexpand

    [DscProperty()]
    [bool] $Icons

    [DscProperty()]
    [bool] $ProblemsBadges

    [DscProperty()]
    [bool] $ProblemsColors

    [DscProperty()]
    [bool] $ProblemsEnabled

    [DscProperty()]
    [bool] $ShowArrays

    [DscProperty()]
    [bool] $ShowBooleans

    [DscProperty()]
    [bool] $ShowClasses

    [DscProperty()]
    [bool] $ShowConstants

    [DscProperty()]
    [bool] $ShowConstructors

    [DscProperty()]
    [bool] $ShowEnumMembers

    [DscProperty()]
    [bool] $ShowEnums

    [DscProperty()]
    [bool] $ShowEvents

    [DscProperty()]
    [bool] $ShowFields

    [DscProperty()]
    [bool] $ShowFiles

    [DscProperty()]
    [bool] $ShowFunctions

    [DscProperty()]
    [bool] $ShowInterfaces

    [DscProperty()]
    [bool] $ShowKeys

    [DscProperty()]
    [bool] $ShowMethods

    [DscProperty()]
    [bool] $ShowModules

    [DscProperty()]
    [bool] $ShowNamespaces

    [DscProperty()]
    [bool] $ShowNull

    [DscProperty()]
    [bool] $ShowNumbers

    [DscProperty()]
    [bool] $ShowObjects

    [DscProperty()]
    [bool] $ShowOperators

    [DscProperty()]
    [bool] $ShowPackages

    [DscProperty()]
    [bool] $ShowProperties

    [DscProperty()]
    [bool] $ShowStrings

    [DscProperty()]
    [bool] $ShowStructs

    [DscProperty()]
    [bool] $ShowTypeParameters

    [DscProperty()]
    [bool] $ShowVariables

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeOutlineSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeOutlineSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeOutlineSetting($settingsFile, $keys) {
        [VSCodeOutlineSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeOutlineSetting] Get() {
        $current = [VSCodeOutlineSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeOutlineSetting]::CurrentSettings

        }

        return [VSCodeOutlineSetting]@{
            CollapseItems      = $this.CollapseItems
            Icons              = $this.Icons
            ProblemsBadges     = $this.ProblemsBadges
            ProblemsColors     = $this.ProblemsColors
            ProblemsEnabled    = $this.ProblemsEnabled
            ShowArrays         = $this.ShowArrays
            ShowBooleans       = $this.ShowBooleans
            ShowClasses        = $this.ShowClasses
            ShowConstants      = $this.ShowConstants
            ShowConstructors   = $this.ShowConstructors
            ShowEnumMembers    = $this.ShowEnumMembers
            ShowEnums          = $this.ShowEnums
            ShowEvents         = $this.ShowEvents
            ShowFields         = $this.ShowFields
            ShowFiles          = $this.ShowFiles
            ShowFunctions      = $this.ShowFunctions
            ShowInterfaces     = $this.ShowInterfaces
            ShowKeys           = $this.ShowKeys
            ShowMethods        = $this.ShowMethods
            ShowModules        = $this.ShowModules
            ShowNamespaces     = $this.ShowNamespaces
            ShowNull           = $this.ShowNull
            ShowNumbers        = $this.ShowNumbers
            ShowObjects        = $this.ShowObjects
            ShowOperators      = $this.ShowOperators
            ShowPackages       = $this.ShowPackages
            ShowProperties     = $this.ShowProperties
            ShowStrings        = $this.ShowStrings
            ShowStructs        = $this.ShowStructs
            ShowTypeParameters = $this.ShowTypeParameters
            ShowVariables      = $this.ShowVariables
            Exist              = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeOutlineSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeOutlineSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeOutlineSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeOutlineSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeOutlineSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeOutlineSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum CollapseItems {
    # Collapse all items.
    Alwayscollapse
    # Expand all items.
    Alwaysexpand
}


[DscResource()]
class VSCodeOutputSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $SmartScrollEnabled

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeOutputSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeOutputSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeOutputSetting($settingsFile, $keys) {
        [VSCodeOutputSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeOutputSetting] Get() {
        $current = [VSCodeOutputSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeOutputSetting]::CurrentSettings

        }

        return [VSCodeOutputSetting]@{
            SmartScrollEnabled = $this.SmartScrollEnabled
            Exist              = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeOutputSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeOutputSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeOutputSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeOutputSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeOutputSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeOutputSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodePackageSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Json

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodePackageSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodePackageSetting]::new($this.SettingsFile, $keys)
    }

    VSCodePackageSetting($settingsFile, $keys) {
        [VSCodePackageSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodePackageSetting] Get() {
        $current = [VSCodePackageSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodePackageSetting]::CurrentSettings

        }

        return [VSCodePackageSetting]@{
            Json  = $this.Json
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodePackageSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodePackageSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodePackageSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodePackageSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePackageSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePackageSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodePathSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Path

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodePathSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodePathSetting]::new($this.SettingsFile, $keys)
    }

    VSCodePathSetting($settingsFile, $keys) {
        [VSCodePathSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodePathSetting] Get() {
        $current = [VSCodePathSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodePathSetting]::CurrentSettings

        }

        return [VSCodePathSetting]@{
            Path  = $this.Path
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodePathSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodePathSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodePathSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodePathSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePathSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePathSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodePhpSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $SuggestBasic

    [DscProperty()]
    [bool] $ValidateEnable

    [DscProperty()]
    [string] $ValidateExecutablePath

    [DscProperty()]
    [string] $ValidateRun

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodePhpSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodePhpSetting]::new($this.SettingsFile, $keys)
    }

    VSCodePhpSetting($settingsFile, $keys) {
        [VSCodePhpSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodePhpSetting] Get() {
        $current = [VSCodePhpSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodePhpSetting]::CurrentSettings

        }

        return [VSCodePhpSetting]@{
            SuggestBasic           = $this.SuggestBasic
            ValidateEnable         = $this.ValidateEnable
            ValidateExecutablePath = $this.ValidateExecutablePath
            ValidateRun            = $this.ValidateRun
            Exist                  = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodePhpSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodePhpSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodePhpSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodePhpSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePhpSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePhpSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeProblemsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AutoReveal

    [DscProperty()]
    [bool] $DecorationsEnabled

    [DscProperty()]
    [string] $DefaultViewMode

    [DscProperty()]
    [bool] $ShowCurrentInStatus

    [DscProperty()]
    [SortOrder] $SortOrder = [SortOrder]::Severity

    [DscProperty()]
    [bool] $Visibility

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeProblemsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeProblemsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeProblemsSetting($settingsFile, $keys) {
        [VSCodeProblemsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeProblemsSetting] Get() {
        $current = [VSCodeProblemsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeProblemsSetting]::CurrentSettings

        }

        return [VSCodeProblemsSetting]@{
            AutoReveal          = $this.AutoReveal
            DecorationsEnabled  = $this.DecorationsEnabled
            DefaultViewMode     = $this.DefaultViewMode
            ShowCurrentInStatus = $this.ShowCurrentInStatus
            SortOrder           = $this.SortOrder
            Visibility          = $this.Visibility
            Exist               = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeProblemsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeProblemsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeProblemsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeProblemsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeProblemsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeProblemsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum SortOrder {
    # Navigate problems ordered by severity
    Severity
    # Navigate problems ordered by position
    Position
}


[DscResource()]
class VSCodePubSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Name

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodePubSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodePubSetting]::new($this.SettingsFile, $keys)
    }

    VSCodePubSetting($settingsFile, $keys) {
        [VSCodePubSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodePubSetting] Get() {
        $current = [VSCodePubSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodePubSetting]::CurrentSettings

        }

        return [VSCodePubSetting]@{
            Name  = $this.Name
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodePubSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodePubSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodePubSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodePubSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePubSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePubSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodePublishSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $Publish

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodePublishSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodePublishSetting]::new($this.SettingsFile, $keys)
    }

    VSCodePublishSetting($settingsFile, $keys) {
        [VSCodePublishSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodePublishSetting] Get() {
        $current = [VSCodePublishSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodePublishSetting]::CurrentSettings

        }

        return [VSCodePublishSetting]@{
            Publish = $this.Publish
            Exist   = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodePublishSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodePublishSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodePublishSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodePublishSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePublishSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePublishSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodePwshSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Pwsh

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodePwshSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodePwshSetting]::new($this.SettingsFile, $keys)
    }

    VSCodePwshSetting($settingsFile, $keys) {
        [VSCodePwshSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodePwshSetting] Get() {
        $current = [VSCodePwshSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodePwshSetting]::CurrentSettings

        }

        return [VSCodePwshSetting]@{
            Pwsh  = $this.Pwsh
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodePwshSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodePwshSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodePwshSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodePwshSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePwshSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePwshSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodePwshCodeSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $PwshCode

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodePwshCodeSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodePwshCodeSetting]::new($this.SettingsFile, $keys)
    }

    VSCodePwshCodeSetting($settingsFile, $keys) {
        [VSCodePwshCodeSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodePwshCodeSetting] Get() {
        $current = [VSCodePwshCodeSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodePwshCodeSetting]::CurrentSettings

        }

        return [VSCodePwshCodeSetting]@{
            PwshCode = $this.PwshCode
            Exist    = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodePwshCodeSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodePwshCodeSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodePwshCodeSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodePwshCodeSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePwshCodeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePwshCodeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodePwshGitSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $PwshGit

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodePwshGitSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodePwshGitSetting]::new($this.SettingsFile, $keys)
    }

    VSCodePwshGitSetting($settingsFile, $keys) {
        [VSCodePwshGitSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodePwshGitSetting] Get() {
        $current = [VSCodePwshGitSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodePwshGitSetting]::CurrentSettings

        }

        return [VSCodePwshGitSetting]@{
            PwshGit = $this.PwshGit
            Exist   = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodePwshGitSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodePwshGitSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodePwshGitSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodePwshGitSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePwshGitSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodePwshGitSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeRedSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [int] $Red

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeRedSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeRedSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeRedSetting($settingsFile, $keys) {
        [VSCodeRedSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeRedSetting] Get() {
        $current = [VSCodeRedSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeRedSetting]::CurrentSettings

        }

        return [VSCodeRedSetting]@{
            Red   = $this.Red
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeRedSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeRedSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeRedSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeRedSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeRedSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeRedSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeReferencesSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [PreferredLocation] $PreferredLocation = [PreferredLocation]::Peek

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeReferencesSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeReferencesSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeReferencesSetting($settingsFile, $keys) {
        [VSCodeReferencesSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeReferencesSetting] Get() {
        $current = [VSCodeReferencesSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeReferencesSetting]::CurrentSettings

        }

        return [VSCodeReferencesSetting]@{
            PreferredLocation = $this.PreferredLocation
            Exist             = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeReferencesSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeReferencesSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeReferencesSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeReferencesSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeReferencesSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeReferencesSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum PreferredLocation {
    # Show references in peek editor.
    Peek
    # Show references in separate view.
    View
}


[DscResource()]
class VSCodeRemoteSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AutoForwardPorts

    [DscProperty()]
    [int] $AutoForwardPortsFallback

    [DscProperty()]
    [AutoForwardPortsSource] $AutoForwardPortsSource = [AutoForwardPortsSource]::Process

    [DscProperty()]
    [bool] $DownloadExtensionsLocally

    [DscProperty()]
    [string] $ExtensionKind

    [DscProperty()]
    [bool] $ForwardOnOpen

    [DscProperty()]
    [string] $LocalPortHost

    [DscProperty()]
    [string] $OtherPortsAttributes

    [DscProperty()]
    [string] $PortsAttributes

    [DscProperty()]
    [bool] $RestoreForwardedPorts

    [DscProperty()]
    [string] $TunnelsAccessHostNameOverride

    [DscProperty()]
    [bool] $TunnelsAccessPreventSleep

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeRemoteSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeRemoteSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeRemoteSetting($settingsFile, $keys) {
        [VSCodeRemoteSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeRemoteSetting] Get() {
        $current = [VSCodeRemoteSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeRemoteSetting]::CurrentSettings

        }

        return [VSCodeRemoteSetting]@{
            AutoForwardPorts              = $this.AutoForwardPorts
            AutoForwardPortsFallback      = $this.AutoForwardPortsFallback
            AutoForwardPortsSource        = $this.AutoForwardPortsSource
            DownloadExtensionsLocally     = $this.DownloadExtensionsLocally
            ExtensionKind                 = $this.ExtensionKind
            ForwardOnOpen                 = $this.ForwardOnOpen
            LocalPortHost                 = $this.LocalPortHost
            OtherPortsAttributes          = $this.OtherPortsAttributes
            PortsAttributes               = $this.PortsAttributes
            RestoreForwardedPorts         = $this.RestoreForwardedPorts
            TunnelsAccessHostNameOverride = $this.TunnelsAccessHostNameOverride
            TunnelsAccessPreventSleep     = $this.TunnelsAccessPreventSleep
            Exist                         = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeRemoteSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeRemoteSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeRemoteSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeRemoteSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeRemoteSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeRemoteSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum AutoForwardPortsSource {
    # Ports will be automatically forwarded when discovered by watching for processes that are started and include a port.
    Process
    # Ports will be automatically forwarded when discovered by reading terminal and debug output. Not all processes that use ports will print to the integrated terminal or debug console, so some ports will be missed. Ports forwarded based on output will not be "un-forwarded" until reload or until the port is closed by the user in the Ports view.
    Output
    # Ports will be automatically forwarded when discovered by reading terminal and debug output. Not all processes that use ports will print to the integrated terminal or debug console, so some ports will be missed. Ports will be "un-forwarded" by watching for processes that listen on that port to be terminated.
    Hybrid
}


[DscResource()]
class VSCodeReplSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $Repl

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeReplSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeReplSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeReplSetting($settingsFile, $keys) {
        [VSCodeReplSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeReplSetting] Get() {
        $current = [VSCodeReplSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeReplSetting]::CurrentSettings

        }

        return [VSCodeReplSetting]@{
            Repl  = $this.Repl
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeReplSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeReplSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeReplSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeReplSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeReplSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeReplSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeScreencastModeSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [int] $FontSize

    [DscProperty()]
    [string] $KeyboardOptions

    [DscProperty()]
    [int] $KeyboardOverlayTimeout

    [DscProperty()]
    [string] $MouseIndicatorColor

    [DscProperty()]
    [int] $MouseIndicatorSize

    [DscProperty()]
    [int] $VerticalOffset

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeScreencastModeSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeScreencastModeSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeScreencastModeSetting($settingsFile, $keys) {
        [VSCodeScreencastModeSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeScreencastModeSetting] Get() {
        $current = [VSCodeScreencastModeSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeScreencastModeSetting]::CurrentSettings

        }

        return [VSCodeScreencastModeSetting]@{
            FontSize               = $this.FontSize
            KeyboardOptions        = $this.KeyboardOptions
            KeyboardOverlayTimeout = $this.KeyboardOverlayTimeout
            MouseIndicatorColor    = $this.MouseIndicatorColor
            MouseIndicatorSize     = $this.MouseIndicatorSize
            VerticalOffset         = $this.VerticalOffset
            Exist                  = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeScreencastModeSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeScreencastModeSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeScreencastModeSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeScreencastModeSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeScreencastModeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeScreencastModeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeScssSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CompletionCompletePropertyWithSemicolon

    [DscProperty()]
    [bool] $CompletionTriggerPropertyValueCompletion

    [DscProperty()]
    [string] $FormatBraceStyle

    [DscProperty()]
    [bool] $FormatEnable

    [DscProperty()]
    [string] $FormatMaxPreserveNewLines

    [DscProperty()]
    [bool] $FormatNewlineBetweenRules

    [DscProperty()]
    [bool] $FormatNewlineBetweenSelectors

    [DscProperty()]
    [bool] $FormatPreserveNewLines

    [DscProperty()]
    [bool] $FormatSpaceAroundSelectorSeparator

    [DscProperty()]
    [bool] $HoverDocumentation

    [DscProperty()]
    [bool] $HoverReferences

    [DscProperty()]
    [string] $LintArgumentsInColorFunction

    [DscProperty()]
    [string] $LintBoxModel

    [DscProperty()]
    [string] $LintCompatibleVendorPrefixes

    [DscProperty()]
    [string] $LintDuplicateProperties

    [DscProperty()]
    [string] $LintEmptyRules

    [DscProperty()]
    [string] $LintFloat

    [DscProperty()]
    [string] $LintFontFaceProperties

    [DscProperty()]
    [string] $LintHexColorLength

    [DscProperty()]
    [string] $LintIdSelector

    [DscProperty()]
    [string] $LintIeHack

    [DscProperty()]
    [string] $LintImportant

    [DscProperty()]
    [string] $LintImportStatement

    [DscProperty()]
    [string] $LintPropertyIgnoredDueToDisplay

    [DscProperty()]
    [string] $LintUniversalSelector

    [DscProperty()]
    [string] $LintUnknownAtRules

    [DscProperty()]
    [string] $LintUnknownProperties

    [DscProperty()]
    [string] $LintUnknownVendorSpecificProperties

    [DscProperty()]
    [string] $LintValidProperties

    [DscProperty()]
    [string] $LintVendorPrefix

    [DscProperty()]
    [string] $LintZeroUnits

    [DscProperty()]
    [bool] $Validate

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeScssSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeScssSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeScssSetting($settingsFile, $keys) {
        [VSCodeScssSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeScssSetting] Get() {
        $current = [VSCodeScssSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeScssSetting]::CurrentSettings

        }

        return [VSCodeScssSetting]@{
            CompletionCompletePropertyWithSemicolon  = $this.CompletionCompletePropertyWithSemicolon
            CompletionTriggerPropertyValueCompletion = $this.CompletionTriggerPropertyValueCompletion
            FormatBraceStyle                         = $this.FormatBraceStyle
            FormatEnable                             = $this.FormatEnable
            FormatMaxPreserveNewLines                = $this.FormatMaxPreserveNewLines
            FormatNewlineBetweenRules                = $this.FormatNewlineBetweenRules
            FormatNewlineBetweenSelectors            = $this.FormatNewlineBetweenSelectors
            FormatPreserveNewLines                   = $this.FormatPreserveNewLines
            FormatSpaceAroundSelectorSeparator       = $this.FormatSpaceAroundSelectorSeparator
            HoverDocumentation                       = $this.HoverDocumentation
            HoverReferences                          = $this.HoverReferences
            LintArgumentsInColorFunction             = $this.LintArgumentsInColorFunction
            LintBoxModel                             = $this.LintBoxModel
            LintCompatibleVendorPrefixes             = $this.LintCompatibleVendorPrefixes
            LintDuplicateProperties                  = $this.LintDuplicateProperties
            LintEmptyRules                           = $this.LintEmptyRules
            LintFloat                                = $this.LintFloat
            LintFontFaceProperties                   = $this.LintFontFaceProperties
            LintHexColorLength                       = $this.LintHexColorLength
            LintIdSelector                           = $this.LintIdSelector
            LintIeHack                               = $this.LintIeHack
            LintImportant                            = $this.LintImportant
            LintImportStatement                      = $this.LintImportStatement
            LintPropertyIgnoredDueToDisplay          = $this.LintPropertyIgnoredDueToDisplay
            LintUniversalSelector                    = $this.LintUniversalSelector
            LintUnknownAtRules                       = $this.LintUnknownAtRules
            LintUnknownProperties                    = $this.LintUnknownProperties
            LintUnknownVendorSpecificProperties      = $this.LintUnknownVendorSpecificProperties
            LintValidProperties                      = $this.LintValidProperties
            LintVendorPrefix                         = $this.LintVendorPrefix
            LintZeroUnits                            = $this.LintZeroUnits
            Validate                                 = $this.Validate
            Exist                                    = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeScssSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeScssSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeScssSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeScssSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeScssSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeScssSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeSearchSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [ActionsPosition] $ActionsPosition = [ActionsPosition]::Right

    [DscProperty()]
    [CollapseResults] $CollapseResults = [CollapseResults]::Alwaysexpand

    [DscProperty()]
    [bool] $DecorationsBadges

    [DscProperty()]
    [bool] $DecorationsColors

    [DscProperty()]
    [DefaultViewMode] $DefaultViewMode = [DefaultViewMode]::List

    [DscProperty()]
    [string] $Exclude

    [DscProperty()]
    [bool] $FollowSymlinks

    [DscProperty()]
    [bool] $GlobalFindClipboard

    [DscProperty()]
    [int] $MaxResults

    [DscProperty()]
    [Mode] $Mode = [Mode]::View

    [DscProperty()]
    [bool] $QuickAccessPreserveInput

    [DscProperty()]
    [QuickOpenHistoryFilterSortOrder] $QuickOpenHistoryFilterSortOrder = [QuickOpenHistoryFilterSortOrder]::Default

    [DscProperty()]
    [bool] $QuickOpenIncludeHistory

    [DscProperty()]
    [bool] $QuickOpenIncludeSymbols

    [DscProperty()]
    [int] $RipgrepMaxThreads

    [DscProperty()]
    [int] $SearchEditorDefaultNumberOfContextLines

    [DscProperty()]
    [SearchEditorDoubleClickBehaviour] $SearchEditorDoubleClickBehaviour = [SearchEditorDoubleClickBehaviour]::Gotolocation

    [DscProperty()]
    [bool] $SearchEditorFocusResultsOnSearch

    [DscProperty()]
    [bool] $SearchEditorReusePriorSearchConfiguration

    [DscProperty()]
    [SearchEditorSingleClickBehaviour] $SearchEditorSingleClickBehaviour = [SearchEditorSingleClickBehaviour]::Default

    [DscProperty()]
    [bool] $SearchOnType

    [DscProperty()]
    [int] $SearchOnTypeDebouncePeriod

    [DscProperty()]
    [bool] $SeedOnFocus

    [DscProperty()]
    [bool] $SeedWithNearestWord

    [DscProperty()]
    [bool] $ShowLineNumbers

    [DscProperty()]
    [bool] $SmartCase

    [DscProperty()]
    [SortOrder] $SortOrder = [SortOrder]::Default

    [DscProperty()]
    [bool] $UseGlobalIgnoreFiles

    [DscProperty()]
    [bool] $UseIgnoreFiles

    [DscProperty()]
    [bool] $UseParentIgnoreFiles

    [DscProperty()]
    [bool] $UseReplacePreview

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeSearchSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeSearchSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeSearchSetting($settingsFile, $keys) {
        [VSCodeSearchSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeSearchSetting] Get() {
        $current = [VSCodeSearchSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeSearchSetting]::CurrentSettings

        }

        return [VSCodeSearchSetting]@{
            ActionsPosition                           = $this.ActionsPosition
            CollapseResults                           = $this.CollapseResults
            DecorationsBadges                         = $this.DecorationsBadges
            DecorationsColors                         = $this.DecorationsColors
            DefaultViewMode                           = $this.DefaultViewMode
            Exclude                                   = $this.Exclude
            FollowSymlinks                            = $this.FollowSymlinks
            GlobalFindClipboard                       = $this.GlobalFindClipboard
            MaxResults                                = $this.MaxResults
            Mode                                      = $this.Mode
            QuickAccessPreserveInput                  = $this.QuickAccessPreserveInput
            QuickOpenHistoryFilterSortOrder           = $this.QuickOpenHistoryFilterSortOrder
            QuickOpenIncludeHistory                   = $this.QuickOpenIncludeHistory
            QuickOpenIncludeSymbols                   = $this.QuickOpenIncludeSymbols
            RipgrepMaxThreads                         = $this.RipgrepMaxThreads
            SearchEditorDefaultNumberOfContextLines   = $this.SearchEditorDefaultNumberOfContextLines
            SearchEditorDoubleClickBehaviour          = $this.SearchEditorDoubleClickBehaviour
            SearchEditorFocusResultsOnSearch          = $this.SearchEditorFocusResultsOnSearch
            SearchEditorReusePriorSearchConfiguration = $this.SearchEditorReusePriorSearchConfiguration
            SearchEditorSingleClickBehaviour          = $this.SearchEditorSingleClickBehaviour
            SearchOnType                              = $this.SearchOnType
            SearchOnTypeDebouncePeriod                = $this.SearchOnTypeDebouncePeriod
            SeedOnFocus                               = $this.SeedOnFocus
            SeedWithNearestWord                       = $this.SeedWithNearestWord
            ShowLineNumbers                           = $this.ShowLineNumbers
            SmartCase                                 = $this.SmartCase
            SortOrder                                 = $this.SortOrder
            UseGlobalIgnoreFiles                      = $this.UseGlobalIgnoreFiles
            UseIgnoreFiles                            = $this.UseIgnoreFiles
            UseParentIgnoreFiles                      = $this.UseParentIgnoreFiles
            UseReplacePreview                         = $this.UseReplacePreview
            Exist                                     = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeSearchSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeSearchSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeSearchSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeSearchSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSearchSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSearchSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum ActionsPosition {
    # Position the actionbar to the right when the search view is narrow, and immediately after the content when the search view is wide.
    Auto
    # Always position the actionbar to the right.
    Right
}

enum CollapseResults {
    # Files with less than 10 results are expanded. Others are collapsed.
    Auto
}

enum DefaultViewMode {
    # Shows search results as a tree.
    Tree
    # Shows search results as a list.
    List
}

enum QuickOpenHistoryFilterSortOrder {
    # History entries are sorted by relevance based on the filter value used. More relevant entries appear first.
    Default
    # History entries are sorted by recency. More recently opened entries appear first.
    Recency
}

enum SearchEditorDoubleClickBehaviour {
    # Double-clicking selects the word under the cursor.
    Selectword
    # Double-clicking opens the result in the active editor group.
    Gotolocation
    # Double-clicking opens the result in the editor group to the side, creating one if it does not yet exist.
    Openlocationtoside
}

enum SearchEditorSingleClickBehaviour {
    # Single-clicking does nothing.
    Default
    # Single-clicking opens a Peek Definition window.
    Peekdefinition
}

[DscResource()]
class VSCodeSecuritySetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $AllowedUNCHosts

    [DscProperty()]
    [bool] $PromptForLocalFileProtocolHandling

    [DscProperty()]
    [bool] $PromptForRemoteFileProtocolHandling

    [DscProperty()]
    [bool] $RestrictUNCAccess

    [DscProperty()]
    [WorkspaceTrustBanner] $WorkspaceTrustBanner = [WorkspaceTrustBanner]::Untildismissed

    [DscProperty()]
    [bool] $WorkspaceTrustEmptyWindow

    [DscProperty()]
    [bool] $WorkspaceTrustEnabled

    [DscProperty()]
    [WorkspaceTrustStartupPrompt] $WorkspaceTrustStartupPrompt = [WorkspaceTrustStartupPrompt]::Once

    [DscProperty()]
    [WorkspaceTrustUntrustedFiles] $WorkspaceTrustUntrustedFiles = [WorkspaceTrustUntrustedFiles]::Prompt

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeSecuritySetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeSecuritySetting]::new($this.SettingsFile, $keys)
    }

    VSCodeSecuritySetting($settingsFile, $keys) {
        [VSCodeSecuritySetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeSecuritySetting] Get() {
        $current = [VSCodeSecuritySetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeSecuritySetting]::CurrentSettings

        }

        return [VSCodeSecuritySetting]@{
            AllowedUNCHosts                     = $this.AllowedUNCHosts
            PromptForLocalFileProtocolHandling  = $this.PromptForLocalFileProtocolHandling
            PromptForRemoteFileProtocolHandling = $this.PromptForRemoteFileProtocolHandling
            RestrictUNCAccess                   = $this.RestrictUNCAccess
            WorkspaceTrustBanner                = $this.WorkspaceTrustBanner
            WorkspaceTrustEmptyWindow           = $this.WorkspaceTrustEmptyWindow
            WorkspaceTrustEnabled               = $this.WorkspaceTrustEnabled
            WorkspaceTrustStartupPrompt         = $this.WorkspaceTrustStartupPrompt
            WorkspaceTrustUntrustedFiles        = $this.WorkspaceTrustUntrustedFiles
            Exist                               = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeSecuritySetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeSecuritySetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeSecuritySetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeSecuritySetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSecuritySetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSecuritySetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum WorkspaceTrustBanner {
    # Show the banner every time an untrusted workspace is open.
    Always
    # Show the banner when an untrusted workspace is opened until dismissed.
    Untildismissed
    # Do not show the banner when an untrusted workspace is open.
    Never
}

enum WorkspaceTrustStartupPrompt {
    # Ask for trust every time an untrusted workspace is opened.
    Always
    # Ask for trust the first time an untrusted workspace is opened.
    Once
    # Do not ask for trust when an untrusted workspace is opened.
    Never
}

enum WorkspaceTrustUntrustedFiles {
    # Ask how to handle untrusted files for each workspace. Once untrusted files are introduced to a trusted workspace, you will not be prompted again.
    Prompt
    # Always allow untrusted files to be introduced to a trusted workspace without prompting.
    Open
    # Always open untrusted files in a separate window in restricted mode without prompting.
    Newwindow
}


[DscResource()]
class VSCodeSettingsSyncSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $IgnoredExtensions

    [DscProperty()]
    [string] $IgnoredSettings

    [DscProperty()]
    [bool] $KeybindingsPerPlatform

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeSettingsSyncSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeSettingsSyncSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeSettingsSyncSetting($settingsFile, $keys) {
        [VSCodeSettingsSyncSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeSettingsSyncSetting] Get() {
        $current = [VSCodeSettingsSyncSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeSettingsSyncSetting]::CurrentSettings

        }

        return [VSCodeSettingsSyncSetting]@{
            IgnoredExtensions      = $this.IgnoredExtensions
            IgnoredSettings        = $this.IgnoredSettings
            KeybindingsPerPlatform = $this.KeybindingsPerPlatform
            Exist                  = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeSettingsSyncSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeSettingsSyncSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeSettingsSyncSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeSettingsSyncSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSettingsSyncSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSettingsSyncSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeShowCommandGroupsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $ShowCommandGroups

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeShowCommandGroupsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeShowCommandGroupsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeShowCommandGroupsSetting($settingsFile, $keys) {
        [VSCodeShowCommandGroupsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeShowCommandGroupsSetting] Get() {
        $current = [VSCodeShowCommandGroupsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeShowCommandGroupsSetting]::CurrentSettings

        }

        return [VSCodeShowCommandGroupsSetting]@{
            ShowCommandGroups = $this.ShowCommandGroups
            Exist             = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeShowCommandGroupsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeShowCommandGroupsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeShowCommandGroupsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeShowCommandGroupsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowCommandGroupsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowCommandGroupsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeShowCommandsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $ShowCommands

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeShowCommandsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeShowCommandsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeShowCommandsSetting($settingsFile, $keys) {
        [VSCodeShowCommandsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeShowCommandsSetting] Get() {
        $current = [VSCodeShowCommandsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeShowCommandsSetting]::CurrentSettings

        }

        return [VSCodeShowCommandsSetting]@{
            ShowCommands = $this.ShowCommands
            Exist        = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeShowCommandsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeShowCommandsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeShowCommandsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeShowCommandsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowCommandsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowCommandsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeShowKeybindingsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $ShowKeybindings

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeShowKeybindingsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeShowKeybindingsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeShowKeybindingsSetting($settingsFile, $keys) {
        [VSCodeShowKeybindingsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeShowKeybindingsSetting] Get() {
        $current = [VSCodeShowKeybindingsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeShowKeybindingsSetting]::CurrentSettings

        }

        return [VSCodeShowKeybindingsSetting]@{
            ShowKeybindings = $this.ShowKeybindings
            Exist           = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeShowKeybindingsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeShowKeybindingsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeShowKeybindingsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeShowKeybindingsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowKeybindingsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowKeybindingsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeShowKeysSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $ShowKeys

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeShowKeysSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeShowKeysSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeShowKeysSetting($settingsFile, $keys) {
        [VSCodeShowKeysSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeShowKeysSetting] Get() {
        $current = [VSCodeShowKeysSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeShowKeysSetting]::CurrentSettings

        }

        return [VSCodeShowKeysSetting]@{
            ShowKeys = $this.ShowKeys
            Exist    = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeShowKeysSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeShowKeysSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeShowKeysSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeShowKeysSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowKeysSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowKeysSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeShowSingleEditorCursorMovesSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $ShowSingleEditorCursorMoves

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeShowSingleEditorCursorMovesSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeShowSingleEditorCursorMovesSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeShowSingleEditorCursorMovesSetting($settingsFile, $keys) {
        [VSCodeShowSingleEditorCursorMovesSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeShowSingleEditorCursorMovesSetting] Get() {
        $current = [VSCodeShowSingleEditorCursorMovesSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeShowSingleEditorCursorMovesSetting]::CurrentSettings

        }

        return [VSCodeShowSingleEditorCursorMovesSetting]@{
            ShowSingleEditorCursorMoves = $this.ShowSingleEditorCursorMoves
            Exist                       = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeShowSingleEditorCursorMovesSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeShowSingleEditorCursorMovesSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeShowSingleEditorCursorMovesSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeShowSingleEditorCursorMovesSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowSingleEditorCursorMovesSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeShowSingleEditorCursorMovesSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeSimpleBrowserSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $FocusLockIndicatorEnabled

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeSimpleBrowserSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeSimpleBrowserSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeSimpleBrowserSetting($settingsFile, $keys) {
        [VSCodeSimpleBrowserSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeSimpleBrowserSetting] Get() {
        $current = [VSCodeSimpleBrowserSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeSimpleBrowserSetting]::CurrentSettings

        }

        return [VSCodeSimpleBrowserSetting]@{
            FocusLockIndicatorEnabled = $this.FocusLockIndicatorEnabled
            Exist                     = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeSimpleBrowserSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeSimpleBrowserSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeSimpleBrowserSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeSimpleBrowserSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSimpleBrowserSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSimpleBrowserSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeSoundSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Sound

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeSoundSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeSoundSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeSoundSetting($settingsFile, $keys) {
        [VSCodeSoundSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeSoundSetting] Get() {
        $current = [VSCodeSoundSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeSoundSetting]::CurrentSettings

        }

        return [VSCodeSoundSetting]@{
            Sound = $this.Sound
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeSoundSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeSoundSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeSoundSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeSoundSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSoundSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSoundSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeStringsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Strings

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeStringsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeStringsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeStringsSetting($settingsFile, $keys) {
        [VSCodeStringsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeStringsSetting] Get() {
        $current = [VSCodeStringsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeStringsSetting]::CurrentSettings

        }

        return [VSCodeStringsSetting]@{
            Strings = $this.Strings
            Exist   = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeStringsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeStringsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeStringsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeStringsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeStringsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeStringsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeSyncSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $Sync

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeSyncSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeSyncSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeSyncSetting($settingsFile, $keys) {
        [VSCodeSyncSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeSyncSetting] Get() {
        $current = [VSCodeSyncSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeSyncSetting]::CurrentSettings

        }

        return [VSCodeSyncSetting]@{
            Sync  = $this.Sync
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeSyncSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeSyncSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeSyncSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeSyncSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSyncSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeSyncSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeTaskSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [AllowAutomaticTasks] $AllowAutomaticTasks = [AllowAutomaticTasks]::On

    [DscProperty()]
    [string] $AutoDetect

    [DscProperty()]
    [bool] $ProblemMatchersNeverPrompt

    [DscProperty()]
    [bool] $QuickOpenDetail

    [DscProperty()]
    [int] $QuickOpenHistory

    [DscProperty()]
    [bool] $QuickOpenShowAll

    [DscProperty()]
    [bool] $QuickOpenSkip

    [DscProperty()]
    [bool] $Reconnection

    [DscProperty()]
    [SaveBeforeRun] $SaveBeforeRun = [SaveBeforeRun]::Always

    [DscProperty()]
    [bool] $SlowProviderWarning

    [DscProperty()]
    [bool] $VerboseLogging

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeTaskSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeTaskSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeTaskSetting($settingsFile, $keys) {
        [VSCodeTaskSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeTaskSetting] Get() {
        $current = [VSCodeTaskSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeTaskSetting]::CurrentSettings

        }

        return [VSCodeTaskSetting]@{
            AllowAutomaticTasks        = $this.AllowAutomaticTasks
            AutoDetect                 = $this.AutoDetect
            ProblemMatchersNeverPrompt = $this.ProblemMatchersNeverPrompt
            QuickOpenDetail            = $this.QuickOpenDetail
            QuickOpenHistory           = $this.QuickOpenHistory
            QuickOpenShowAll           = $this.QuickOpenShowAll
            QuickOpenSkip              = $this.QuickOpenSkip
            Reconnection               = $this.Reconnection
            SaveBeforeRun              = $this.SaveBeforeRun
            SlowProviderWarning        = $this.SlowProviderWarning
            VerboseLogging             = $this.VerboseLogging
            Exist                      = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeTaskSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeTaskSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeTaskSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeTaskSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTaskSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTaskSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum AllowAutomaticTasks {
    # Always
    On
    # Never
    Off
}

enum SaveBeforeRun {
    # Always saves all editors before running.
    Always
    # Never saves editors before running.
    Never
    # Prompts whether to save editors before running.
    Prompt
}


[DscResource()]
class VSCodeTelemetrySetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [TelemetryLevel] $TelemetryLevel = [TelemetryLevel]::All

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeTelemetrySetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeTelemetrySetting]::new($this.SettingsFile, $keys)
    }

    VSCodeTelemetrySetting($settingsFile, $keys) {
        [VSCodeTelemetrySetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeTelemetrySetting] Get() {
        $current = [VSCodeTelemetrySetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeTelemetrySetting]::CurrentSettings

        }

        return [VSCodeTelemetrySetting]@{
            TelemetryLevel = $this.TelemetryLevel
            Exist          = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeTelemetrySetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeTelemetrySetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeTelemetrySetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeTelemetrySetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTelemetrySetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTelemetrySetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum TelemetryLevel {
    # Sends usage data, errors, and crash reports.
    All
    # Sends general error telemetry and crash reports.
    Error
    # Sends OS level crash reports.
    Crash
    # Disables all product telemetry.
    Off
}


[DscResource()]
class VSCodeTerminalEditorSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $TerminalEditor

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeTerminalEditorSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeTerminalEditorSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeTerminalEditorSetting($settingsFile, $keys) {
        [VSCodeTerminalEditorSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeTerminalEditorSetting] Get() {
        $current = [VSCodeTerminalEditorSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeTerminalEditorSetting]::CurrentSettings

        }

        return [VSCodeTerminalEditorSetting]@{
            TerminalEditor = $this.TerminalEditor
            Exist          = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeTerminalEditorSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeTerminalEditorSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeTerminalEditorSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeTerminalEditorSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTerminalEditorSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTerminalEditorSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeTestingSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AlwaysRevealTestOnStateChange

    [DscProperty()]
    [AutomaticallyOpenPeekView] $AutomaticallyOpenPeekView = [AutomaticallyOpenPeekView]::Failureinvisibledocument

    [DscProperty()]
    [bool] $AutomaticallyOpenPeekViewDuringAutoRun

    [DscProperty()]
    [int] $AutoRunDelay

    [DscProperty()]
    [CountBadge] $CountBadge = [CountBadge]::Failed

    [DscProperty()]
    [string] $CoverageBarThresholds

    [DscProperty()]
    [bool] $CoverageToolbarEnabled

    [DscProperty()]
    [DefaultGutterClickAction] $DefaultGutterClickAction = [DefaultGutterClickAction]::Run

    [DscProperty()]
    [DisplayedCoveragePercent] $DisplayedCoveragePercent = [DisplayedCoveragePercent]::Totalcoverage

    [DscProperty()]
    [bool] $FollowRunningTest

    [DscProperty()]
    [bool] $GutterEnabled

    [DscProperty()]
    [OpenTesting] $OpenTesting = [OpenTesting]::Openonteststart

    [DscProperty()]
    [bool] $SaveBeforeTest

    [DscProperty()]
    [bool] $ShowAllMessages

    [DscProperty()]
    [bool] $ShowCoverageInExplorer

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeTestingSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeTestingSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeTestingSetting($settingsFile, $keys) {
        [VSCodeTestingSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeTestingSetting] Get() {
        $current = [VSCodeTestingSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeTestingSetting]::CurrentSettings

        }

        return [VSCodeTestingSetting]@{
            AlwaysRevealTestOnStateChange          = $this.AlwaysRevealTestOnStateChange
            AutomaticallyOpenPeekView              = $this.AutomaticallyOpenPeekView
            AutomaticallyOpenPeekViewDuringAutoRun = $this.AutomaticallyOpenPeekViewDuringAutoRun
            AutoRunDelay                           = $this.AutoRunDelay
            CountBadge                             = $this.CountBadge
            CoverageBarThresholds                  = $this.CoverageBarThresholds
            CoverageToolbarEnabled                 = $this.CoverageToolbarEnabled
            DefaultGutterClickAction               = $this.DefaultGutterClickAction
            DisplayedCoveragePercent               = $this.DisplayedCoveragePercent
            FollowRunningTest                      = $this.FollowRunningTest
            GutterEnabled                          = $this.GutterEnabled
            OpenTesting                            = $this.OpenTesting
            SaveBeforeTest                         = $this.SaveBeforeTest
            ShowAllMessages                        = $this.ShowAllMessages
            ShowCoverageInExplorer                 = $this.ShowCoverageInExplorer
            Exist                                  = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeTestingSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeTestingSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeTestingSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeTestingSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTestingSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTestingSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum AutomaticallyOpenPeekView {
    # Open automatically no matter where the failure is.
    Failureanywhere
    # Open automatically when a test fails in a visible document.
    Failureinvisibledocument
    # Never automatically open.
    Never
}

enum CountBadge {
    # Show the number of failed tests
    Failed
    # Disable the testing count badge
    Off
    # Show the number of passed tests
    Passed
    # Show the number of skipped tests
    Skipped
}

enum DefaultGutterClickAction {
    # Run the test.
    Run
    # Debug the test.
    Debug
    # Run the test with coverage.
    Runwithcoverage
    # Open the context menu for more options.
    Contextmenu
}

enum DisplayedCoveragePercent {
    # A calculation of the combined statement, function, and branch coverage.
    Totalcoverage
    # The statement coverage.
    Statement
    # The minimum of statement, function, and branch coverage.
    Minimum
}

enum OpenTesting {
    # Never automatically open the testing views
    Neveropen
    # Open the test results view when tests start
    Openonteststart
    # Open the test result view on any test failure
    Openontestfailure
    # Open the test explorer when tests start
    Openexploreronteststart
}


[DscResource()]
class VSCodeTimelineSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $PageOnScroll

    [DscProperty()]
    [string] $PageSize

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeTimelineSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeTimelineSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeTimelineSetting($settingsFile, $keys) {
        [VSCodeTimelineSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeTimelineSetting] Get() {
        $current = [VSCodeTimelineSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeTimelineSetting]::CurrentSettings

        }

        return [VSCodeTimelineSetting]@{
            PageOnScroll = $this.PageOnScroll
            PageSize     = $this.PageSize
            Exist        = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeTimelineSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeTimelineSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeTimelineSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeTimelineSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTimelineSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTimelineSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeTmuxSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Tmux

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeTmuxSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeTmuxSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeTmuxSetting($settingsFile, $keys) {
        [VSCodeTmuxSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeTmuxSetting] Get() {
        $current = [VSCodeTmuxSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeTmuxSetting]::CurrentSettings

        }

        return [VSCodeTmuxSetting]@{
            Tmux  = $this.Tmux
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeTmuxSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeTmuxSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeTmuxSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeTmuxSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTmuxSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTmuxSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeTsconfigSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Json

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeTsconfigSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeTsconfigSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeTsconfigSetting($settingsFile, $keys) {
        [VSCodeTsconfigSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeTsconfigSetting] Get() {
        $current = [VSCodeTsconfigSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeTsconfigSetting]::CurrentSettings

        }

        return [VSCodeTsconfigSetting]@{
            Json  = $this.Json
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeTsconfigSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeTsconfigSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeTsconfigSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeTsconfigSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTsconfigSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeTsconfigSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeUntitledEditorsSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $UntitledEditors

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeUntitledEditorsSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeUntitledEditorsSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeUntitledEditorsSetting($settingsFile, $keys) {
        [VSCodeUntitledEditorsSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeUntitledEditorsSetting] Get() {
        $current = [VSCodeUntitledEditorsSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeUntitledEditorsSetting]::CurrentSettings

        }

        return [VSCodeUntitledEditorsSetting]@{
            UntitledEditors = $this.UntitledEditors
            Exist           = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeUntitledEditorsSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeUntitledEditorsSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeUntitledEditorsSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeUntitledEditorsSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeUntitledEditorsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeUntitledEditorsSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeUpdateSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $EnableWindowsBackgroundUpdates

    [DscProperty()]
    [Mode] $Mode = [Mode]::Default

    [DscProperty()]
    [bool] $ShowReleaseNotes

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeUpdateSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeUpdateSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeUpdateSetting($settingsFile, $keys) {
        [VSCodeUpdateSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeUpdateSetting] Get() {
        $current = [VSCodeUpdateSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeUpdateSetting]::CurrentSettings

        }

        return [VSCodeUpdateSetting]@{
            EnableWindowsBackgroundUpdates = $this.EnableWindowsBackgroundUpdates
            Mode                           = $this.Mode
            ShowReleaseNotes               = $this.ShowReleaseNotes
            Exist                          = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeUpdateSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeUpdateSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeUpdateSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeUpdateSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeUpdateSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeUpdateSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

[DscResource()]
class VSCodeVscodeSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AudioPreview

    [DscProperty()]
    [bool] $VideoPreview

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeVscodeSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeVscodeSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeVscodeSetting($settingsFile, $keys) {
        [VSCodeVscodeSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeVscodeSetting] Get() {
        $current = [VSCodeVscodeSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeVscodeSetting]::CurrentSettings

        }

        return [VSCodeVscodeSetting]@{
            AudioPreview = $this.AudioPreview
            VideoPreview = $this.VideoPreview
            Exist        = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeVscodeSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeVscodeSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeVscodeSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeVscodeSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeVscodeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeVscodeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}


[DscResource()]
class VSCodeWindowSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $AutoDetectColorScheme

    [DscProperty()]
    [bool] $AutoDetectHighContrast

    [DscProperty()]
    [bool] $ClickThroughInactive

    [DscProperty()]
    [bool] $CloseWhenEmpty

    [DscProperty()]
    [bool] $CommandCenter

    [DscProperty()]
    [ConfirmBeforeClose] $ConfirmBeforeClose = [ConfirmBeforeClose]::Never

    [DscProperty()]
    [bool] $ConfirmSaveUntitledWorkspace

    [DscProperty()]
    [bool] $CustomMenuBarAltFocus

    [DscProperty()]
    [CustomTitleBarVisibility] $CustomTitleBarVisibility = [CustomTitleBarVisibility]::Auto

    [DscProperty()]
    [string] $DensityEditorTabHeight

    [DscProperty()]
    [string] $DialogStyle

    [DscProperty()]
    [bool] $DoubleClickIconToClose

    [DscProperty()]
    [bool] $EnableMenuBarMnemonics

    [DscProperty()]
    [MenuBarVisibility] $MenuBarVisibility = [MenuBarVisibility]::Classic

    [DscProperty()]
    [bool] $NativeFullScreen

    [DscProperty()]
    [bool] $NativeTabs

    [DscProperty()]
    [NewWindowDimensions] $NewWindowDimensions = [NewWindowDimensions]::Default

    [DscProperty()]
    [string] $NewWindowProfile

    [DscProperty()]
    [OpenFilesInNewWindow] $OpenFilesInNewWindow = [OpenFilesInNewWindow]::Off

    [DscProperty()]
    [OpenFoldersInNewWindow] $OpenFoldersInNewWindow = [OpenFoldersInNewWindow]::Default

    [DscProperty()]
    [OpenWithoutArgumentsInNewWindow] $OpenWithoutArgumentsInNewWindow = [OpenWithoutArgumentsInNewWindow]::On

    [DscProperty()]
    [bool] $RestoreFullscreen

    [DscProperty()]
    [RestoreWindows] $RestoreWindows = [RestoreWindows]::All

    [DscProperty()]
    [SystemColorTheme] $SystemColorTheme = [SystemColorTheme]::Default

    [DscProperty()]
    [string] $Title

    [DscProperty()]
    [string] $TitleBarStyle

    [DscProperty()]
    [string] $TitleSeparator

    [DscProperty()]
    [int] $ZoomLevel

    [DscProperty()]
    [bool] $ZoomPerWindow

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeWindowSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeWindowSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeWindowSetting($settingsFile, $keys) {
        [VSCodeWindowSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeWindowSetting] Get() {
        $current = [VSCodeWindowSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeWindowSetting]::CurrentSettings

        }

        return [VSCodeWindowSetting]@{
            AutoDetectColorScheme           = $this.AutoDetectColorScheme
            AutoDetectHighContrast          = $this.AutoDetectHighContrast
            ClickThroughInactive            = $this.ClickThroughInactive
            CloseWhenEmpty                  = $this.CloseWhenEmpty
            CommandCenter                   = $this.CommandCenter
            ConfirmBeforeClose              = $this.ConfirmBeforeClose
            ConfirmSaveUntitledWorkspace    = $this.ConfirmSaveUntitledWorkspace
            CustomMenuBarAltFocus           = $this.CustomMenuBarAltFocus
            CustomTitleBarVisibility        = $this.CustomTitleBarVisibility
            DensityEditorTabHeight          = $this.DensityEditorTabHeight
            DialogStyle                     = $this.DialogStyle
            DoubleClickIconToClose          = $this.DoubleClickIconToClose
            EnableMenuBarMnemonics          = $this.EnableMenuBarMnemonics
            MenuBarVisibility               = $this.MenuBarVisibility
            NativeFullScreen                = $this.NativeFullScreen
            NativeTabs                      = $this.NativeTabs
            NewWindowDimensions             = $this.NewWindowDimensions
            NewWindowProfile                = $this.NewWindowProfile
            OpenFilesInNewWindow            = $this.OpenFilesInNewWindow
            OpenFoldersInNewWindow          = $this.OpenFoldersInNewWindow
            OpenWithoutArgumentsInNewWindow = $this.OpenWithoutArgumentsInNewWindow
            RestoreFullscreen               = $this.RestoreFullscreen
            RestoreWindows                  = $this.RestoreWindows
            SystemColorTheme                = $this.SystemColorTheme
            Title                           = $this.Title
            TitleBarStyle                   = $this.TitleBarStyle
            TitleSeparator                  = $this.TitleSeparator
            ZoomLevel                       = $this.ZoomLevel
            ZoomPerWindow                   = $this.ZoomPerWindow
            Exist                           = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeWindowSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeWindowSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeWindowSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeWindowSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeWindowSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeWindowSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum ConfirmBeforeClose {
    # Always ask for confirmation.
    Always
    # Only ask for confirmation if a keybinding was used.
    Keyboardonly
    # Never explicitly ask for confirmation.
    Never
}

enum CustomTitleBarVisibility {
    # Automatically changes custom title bar visibility.
    Auto
    # Hide custom titlebar in full screen. When not in full screen, automatically change custom title bar visibility.
    Windowed
    # Hide custom titlebar when `window.titleBarStyle` is set to `native`.
    Never
}

enum MenuBarVisibility {
    # Menu is displayed at the top of the window and only hidden in full screen mode.
    Classic
    # Menu is always visible at the top of the window even in full screen mode.
    Visible
    # Menu is hidden but can be displayed at the top of the window via the Alt key.
    Toggle
    # Menu is always hidden.
    Hidden
    # Menu is displayed as a compact button in the side bar. This value is ignored when `window.titleBarStyle` is `native`.
    Compact
}

enum NewWindowDimensions {
    # Open new windows in the center of the screen.
    Default
    # Open new windows with same dimension as last active one.
    Inherit
    # Open new windows with same dimension as last active one with an offset position.
    Offset
    # Open new windows maximized.
    Maximized
    # Open new windows in full screen mode.
    Fullscreen
}

enum OpenFilesInNewWindow {
    # Files will open in a new window.
    On
    # Files will open in the window with the files' folder open or the last active window.
    Off
    # Files will open in a new window unless picked from within the application (e.g. via the File menu).
    Default
}

enum OpenFoldersInNewWindow {
    # Folders will open in a new window.
    On
    # Folders will replace the last active window.
    Off
    # Folders will open in a new window unless a folder is picked from within the application (e.g. via the File menu).
    Default
}

enum OpenWithoutArgumentsInNewWindow {
    # Open a new empty window.
    On
    # Focus the last active running instance.
    Off
}

enum RestoreWindows {
    # Always reopen all windows. If a folder or workspace is opened (e.g. from the command line) it opens as a new window unless it was opened before. If files are opened they will open in one of the restored windows together with editors that were previously opened.
    Preserve
    # Reopen all windows unless a folder, workspace or file is opened (e.g. from the command line). If a file is opened, it will replace any of the editors that were previously opened in a window.
    All
    # Reopen all windows that had folders or workspaces opened unless a folder, workspace or file is opened (e.g. from the command line). If a file is opened, it will replace any of the editors that were previously opened in a window.
    Folders
    # Reopen the last active window unless a folder, workspace or file is opened (e.g. from the command line). If a file is opened, it will replace any of the editors that were previously opened in a window.
    One
    # Never reopen a window. Unless a folder or workspace is opened (e.g. from the command line), an empty window will appear.
    None
}

enum SystemColorTheme {
    # Native element colors match the system colors.
    Default
    # Use light native element colors for light color themes and dark for dark color themes.
    Auto
    # Use light native element colors.
    Light
    # Use dark native element colors.
    Dark
}


[DscResource()]
class VSCodeYellowSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [int] $Yellow

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeYellowSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeYellowSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeYellowSetting($settingsFile, $keys) {
        [VSCodeYellowSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeYellowSetting] Get() {
        $current = [VSCodeYellowSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeYellowSetting]::CurrentSettings

        }

        return [VSCodeYellowSetting]@{
            Yellow = $this.Yellow
            Exist  = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeYellowSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeYellowSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeYellowSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeYellowSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeYellowSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeYellowSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

[DscResource()]
class VSCodeZenModeSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [bool] $CenterLayout

    [DscProperty()]
    [bool] $FullScreen

    [DscProperty()]
    [bool] $HideActivityBar

    [DscProperty()]
    [bool] $HideLineNumbers

    [DscProperty()]
    [bool] $HideStatusBar

    [DscProperty()]
    [bool] $Restore

    [DscProperty()]
    [ShowTabs] $ShowTabs = [ShowTabs]::Multiple

    [DscProperty()]
    [bool] $SilentNotifications

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeZenModeSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeZenModeSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeZenModeSetting($settingsFile, $keys) {
        [VSCodeZenModeSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeZenModeSetting] Get() {
        $current = [VSCodeZenModeSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeZenModeSetting]::CurrentSettings

        }

        return [VSCodeZenModeSetting]@{
            CenterLayout        = $this.CenterLayout
            FullScreen          = $this.FullScreen
            HideActivityBar     = $this.HideActivityBar
            HideLineNumbers     = $this.HideLineNumbers
            HideStatusBar       = $this.HideStatusBar
            Restore             = $this.Restore
            ShowTabs            = $this.ShowTabs
            SilentNotifications = $this.SilentNotifications
            Exist               = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeZenModeSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeZenModeSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeZenModeSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeZenModeSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeZenModeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeZenModeSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }

}

enum ShowTabs {
    # Each editor is displayed as a tab in the editor title area.
    Multiple
    # The active editor is displayed as a single large tab in the editor title area.
    Single
    # The editor title area is not displayed.
    None
}


[DscResource()]
class VSCodeZshSetting {
    [DscProperty(Key)]
    [string] $SettingsFile = (Get-VSCodeSettingsFile)

    [DscProperty()]
    [string] $Zsh

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $CurrentSettings

    VSCodeZshSetting() {
        $keys = $this.ToHashTable($false)
        [VSCodeZshSetting]::new($this.SettingsFile, $keys)
    }

    VSCodeZshSetting($settingsFile, $keys) {
        [VSCodeZshSetting]::GetCurrentSettings($settingsFile, $keys)
    }

    [VSCodeZshSetting] Get() {
        $current = [VSCodeZshSetting]::CurrentSettings

        $props = $this.ToHashTable($true) | Get-ClassOnlyProperty

        $currentState = Test-CurrentState -current $current -props $props

        if ($currentState)
        {
            return [VSCodeZshSetting]::CurrentSettings

        }

        return [VSCodeZshSetting]@{
            Zsh   = $this.Zsh
            Exist = $false
        }

    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.SetSetting($false)
        }

        else {
            $this.UnSetSetting($false)
        }

    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false

        }

        return $true

    }

    [VSCodeZshSetting[]] Export() {
        $file = $this.SettingsFile 

        $properties = $this.ToHashTable($false)

        [VSCodeZshSetting]::GetCurrentSettings($file, $Properties)

        return [VSCodeZshSetting]::CurrentSettings

    }

    [hashtable] ToHashTable([bool] $OnlySetProperties) {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if ($OnlySetProperties) {
                if (-not ([string]::IsNullOrEmpty($property.Value))) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            else {
                $parameters[$property.Name] = $property.Value
            }
        }
        return $parameters
    }

    static [void] GetCurrentSettings([string] $settingsFile, [hashtable] $properties) {
        $current = Get-VSCodeCurrentSettings -settingsFile $settingsFile -properties $properties

        [VSCodeZshSetting]::CurrentSettings = $current
    }

    [void] SetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        New-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeZshSetting]::GetCurrentSettings

    }

    [void] UnSetSetting([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        $settings = $this.ToHashTable($true)

        Clear-VSCodeWorkSpaceSetting -settingsFile $this.SettingsFile -settingTable $settings

        [VSCodeZshSetting]::GetCurrentSettings

    }

    [void] UnSetSetting() {
        $this.UnSetSetting($true)
    }
}

#endregion DSCResources


