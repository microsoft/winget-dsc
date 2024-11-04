# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

$global:LocaleNameRegistryPath = "HKCU:\Control Panel\International"
$global:LocaleUserProfilePath = "HKCU:\Control Panel\International\User Profile"

#region Functions
function Get-OsBuildVersion 
{
    return [System.Environment]::OSVersion.Version.Build
}

function Set-LocaleByOs 
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$LocaleName
    )

    if (Test-Win11OrServer2022)
    {
        if (Test-LocaleByOs -LocaleName $LocaleName)
        {
            Set-WinUserLanguageList -Language $LocaleName
        }
    }
    # TODO: Add support for older OS versions
    # Challenging to get input method tips for older OS versions
    else
    {
        Throw "This module only supports Windows 11 and Windows Server 2022."
    }
}

function Test-Win11OrServer2022 
{
    $osBuildVersion = Get-OsBuildVersion

    if ($osBuildVersion -gt 26100 -or $osBuildVersion -gt 20348)
    {
        return $true
    }

    return $false
}

function Test-LocaleByOs 
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$LocaleName
    )

    $osBuildVersion = Get-OsBuildVersion

    if ($osBuildVersion -gt 26100 -or $osBuildVersion -gt 20348)
    {
        $languageList = Get-WinUserLanguageList
        if ($languageList.Language -in $LocaleName)
        {
            return $true
        }
        else 
        {
            Throw "Language `"$($LocaleName)`" is not installed. Please make sure the language is installed on the system first."
        }
    }
}

function TryGetRegistryValue
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Property
    )    

    if (Test-Path -Path $Key)
    {
        try
        {
            return (Get-ItemProperty -Path $Key | Select-Object -ExpandProperty $Property)     
        }
        catch
        {
            Write-Verbose "Property `"$($Property)`" could not be found."
        }
    }
    else
    {
        Write-Verbose "Registry key does not exist."
    }
}

function Get-LocaleList
{
    # TODO: Add support for older OS versions
    $localeList = Get-WinUserLanguageList
    $out = [List[Language]]::new()

    foreach ($locale in $localeList)
    {
        $langague = [Language]::new($locale.LanguageTag, $true)
        $out.Add($langague)
    }

    # section to include other languages that can be installed
    # helpful for users to discover what packages can be installed
    $allLangues = [System.Globalization.CultureInfo]::GetCultures("AllCultures")
    foreach ($culture in $allLangues)
    {
        if ($out.LocaleName -notcontains $culture.Name -and -not ([string]::IsNullOrEmpty($culture.Name)))  
        {
            $langague = [Language]::new($culture.Name, $false)
            $out.Add($langague)
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
class Language 
{
    [DscProperty(Key)]
    [string] $LocaleName

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $InstalledLocality

    Language()
    {
        [Language]::GetInstalledLocality()
    }

    Language([string] $LocaleName, [bool] $Exist)
    {
        $this.LocaleName = $LocaleName
        $this.Exist = $Exist
    }

    [Language] Get()
    {
        $keyExist = [Language]::InstalledLocality.ContainsKey(($this.LocaleName))

        $currentState = [Language]::InstalledLocality[$this.LocaleName]

        if (-not $keyExist)
        {
            return [Language]::new($this.LocaleName, $false)
        }
        
        return $currentState
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        if (Test-Win11OrServer2022)
        {
            if ($this.Exist)
            {
                # use the LanguagePackManagement module to install the language (requires elevation). International does not have a cmdlet to install language
                Install-Language -Language $this.LocaleName
            }
            else 
            {
                Uninstall-Language -Language $this.LocaleName
            }
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false
        }
        
        return $true
    }

    static [Language[]] Export()
    {
        return Get-LocaleList
    }

    #region Language helper functions
    static [void] GetInstalledLocality()
    {   
        [Language]::InstalledLocality = @{}

        foreach ($locality in [Language]::Export())
        {
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
class DisplayLanguage
{
    
    [DscProperty(Key)]
    [string] $LocaleName

    [DscProperty()]
    [bool] $Exist = $true

    hidden [string] $KeyName = 'LocaleName'

    DisplayLanguage()
    {
        $this
    }

    [DisplayLanguage] Get()
    {
        $currentState = [DisplayLanguage]::new()

        # check if user profile contains display language
        $userProfileLanguageDict = TryGetRegistryValue -Key (Join-path $global:LocaleUserProfilePath $this.LocaleName) -Property 'CachedLanguageName'
        if ((TryGetRegistryValue -Key $global:LocaleNameRegistryPath -Property $this.KeyName) -ne $this.LocaleName -and ($null -ne $userProfileLanguageDict))
        {
            $currentState.Exist = $false
            return $currentState
        }

        return @{
            LocaleName = $this.LocaleName
            Exist      = $true
        }
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        # TODO: How do we handle sign out and sign in?
        Set-LocaleByOs -LocaleName $this.LocaleName

        # TODO: Exist does not make sense here, we always want a language to exist
    }

    [bool] Test()
    {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false
        }
        
        return $true
    }
}
#endRegion classes
