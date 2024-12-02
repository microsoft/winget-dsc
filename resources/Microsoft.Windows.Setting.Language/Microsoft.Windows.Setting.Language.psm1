# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:LocaleNameRegistryPath = 'HKCU:\Control Panel\International'
    $global:LocaleUserProfilePath = 'HKCU:\Control Panel\International\User Profile'
} else {
    $global:LocaleNameRegistryPath = $global:LocaleUserProfilePath = $env:TestRegistryPath
}

#region Functions

function TryGetRegistryValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Property
    )    

    if (Test-Path -Path $Key) {
        try {
            return (Get-ItemProperty -Path $Key | Select-Object -ExpandProperty $Property)     
        } catch {
            Write-Verbose "Property `"$($Property)`" could not be found."
        }
    } else {
        Write-Verbose 'Registry key does not exist.'
    }
}

function Get-LocaleList {
    $localeList = Get-WinUserLanguageList
    $out = [List[Language]]::new()

    foreach ($locale in $localeList) {
        $language = [Language]::new($locale.LanguageTag, $true)
        $out.Add($language)
    }

    # section to include other languages that can be installed
    # helpful for users to discover what packages can be installed
    $allLanguages = [System.Globalization.CultureInfo]::GetCultures('AllCultures')
    foreach ($culture in $allLanguages) {
        if ($out.LocaleName -notcontains $culture.Name -and -not ([string]::IsNullOrEmpty($culture.Name))) {
            $language = [Language]::new($culture.Name, $false)
            $out.Add($language)
        }
    }

    return $out
}
#endregion Functions

#region Classes
<#
.SYNOPSIS
    The `Language` DSC Resource allows you to install, update, and uninstall languages on your local Windows machine.

.PARAMETER LocaleName
    The name of the language. This is the language tag that represents the language. For example, `en-US` represents English (United States).
    To get a full list of languages available, use the `Get-LocaleList` function or Export() method.

.PARAMETER Exist
    Indicates whether the package should exist. Defaults to $true.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Language -Name Language -Method Set -Property @{ LocaleName = 'en-US' }

    This example installs the English (United States) language on the local machine.
#>
[DscResource()]
class Language {
    [DscProperty(Key)]
    [string] $LocaleName

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $InstalledLocality

    Language() {
        [Language]::GetInstalledLocality()
    }

    Language([string] $LocaleName, [bool] $Exist) {
        $this.LocaleName = $LocaleName
        $this.Exist = $Exist
    }

    [Language] Get() {
        $keyExist = [Language]::InstalledLocality.ContainsKey(($this.LocaleName))

        $currentState = [Language]::InstalledLocality[$this.LocaleName]

        if (-not $keyExist) {
            return [Language]::new($this.LocaleName, $false)
        }
        
        return $currentState
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            # use the LanguagePackManagement module to install the language (requires elevation). International does not have a cmdlet to install language
            Install-Language -Language $this.LocaleName
        } else {
            Uninstall-Language -Language $this.LocaleName
        }
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist) {
            return $false
        }
        
        return $true
    }

    static [Language[]] Export() {
        return Get-LocaleList
    }

    #region Language helper functions
    static [void] GetInstalledLocality() {   
        [Language]::InstalledLocality = @{}

        foreach ($locality in [Language]::Export()) {
            [Language]::InstalledLocality[$locality.LocaleName] = $locality
        }
    }
    #endRegion Language helper functions
}

<#
.SYNOPSIS
    The `DisplayLanguage` DSC Resource allows you to set the display language on your local Windows machine.

.PARAMETER LocaleName
    The name of the display language. This is the language tag that represents the language. For example, `en-US` represents English (United States).

.PARAMETER Exist
    Indicates whether the display language should be set. Defaults to $true.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Language -Name DisplayLanguage -Method Set -Property @{ LocaleName = 'en-US' }

    This example sets the display language to English (United States) on the user.
#>
[DscResource()]
class DisplayLanguage {
    
    [DscProperty(Key)]
    [string] $LocaleName

    [DscProperty()]
    [bool] $Exist = $true

    hidden [string] $KeyName = 'LocaleName'

    DisplayLanguage() {
    }

    [DisplayLanguage] Get() {
        $currentState = [DisplayLanguage]::new()

        # check if user profile contains display language
        $userProfileLanguageDict = TryGetRegistryValue -Key (Join-Path $global:LocaleUserProfilePath $this.LocaleName) -Property 'CachedLanguageName'
        if ((TryGetRegistryValue -Key $global:LocaleNameRegistryPath -Property $this.KeyName) -ne $this.LocaleName -and ($null -ne $userProfileLanguageDict)) {
            $currentState.Exist = $false
            return $currentState
        }

        return @{
            LocaleName = $this.LocaleName
            Exist      = $true
        }
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        # TODO: How do we handle sign out and sign in?
        Set-WinUserLanguageList -Language $this.LocaleName

        # TODO: Exist does not make sense here, we always want a language to exist
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist) {
            return $false
        }
        
        return $true
    }
}
#endRegion classes
