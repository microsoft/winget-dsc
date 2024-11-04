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
#endregion Functions

#region Classes
[DscResource()]
class Language
{
    
    [DscProperty(Key)]
    [string] $LocaleName

    [DscProperty()]
    [bool] $Exist = $true

    hidden [string] $KeyName = 'LocaleName'

    Language()
    {
        $this
    }

    [Language] Get()
    {
        $currentState = [Language]::new()

        # check if user profile contains language
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
