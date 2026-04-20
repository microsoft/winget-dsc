function Initialize-ResourceFile {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ModuleName,

        [Parameter(Mandatory = $true)]
        [string] $ResourceName,

        [Parameter(Mandatory = $true)]
        [string] $Synopsis,

        [Parameter(Mandatory = $true)]
        [string] $Description
    )

    $initialContent = @(
        '---',
        "external help file: $ModuleName-Help.xml",
        "Module Name: $ModuleName",
        "ms.date: $(Get-Date -Format 'MM/dd/yyyy')",
        "online version: $null",
        'schema: 2.0.0',
        "title: $ResourceName",
        '---',
        '',
        "# $ResourceName",
        '',
        '## SYNOPSIS',
        '',
        $Synopsis,
        '',
        '## DESCRIPTION',
        '',
        $Description,
        ''
    ) | Where-Object { $null -ne $_ } # Filter null values
    $readMeFileContent = $initialContent

    return $readMeFileContent
}

function Get-TypeInstanceFromModule {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ModuleName,
        [Parameter(Mandatory = $true)]
        [string] $ClassName
    )
    $instance = & (Import-Module $ModuleName -PassThru) ([scriptblock]::Create("'$ClassName' -as 'type'"))
    return $instance
}

function Set-ResourcePropertyParameters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $ParameterFileContent,

        [Parameter(Mandatory = $true)]
        [object[]] $FileContent
    )

    $parameterSection = @(
        '## PARAMETERS',
        '',
        '| **Parameter** | **Attribute** | **DataType** | **Description** | **Allowed values** |',
        '| :------------ | :------------ | :----------- | :-------------- | :----------------- |'
    )

    $ParameterFileContent.GetEnumerator() | ForEach-Object {
        $Attribute = $_.Value.Required ? 'Mandatory' : 'Optional'
        $DataType = $_.Value.Type
        $Description = $_.Value.Description
        $AllowedValues = $null # TOCO: Figure a way to get allowed values
        $parameterSection += '| {0} | {1} | {2} | {3} | {4} |' -f $_.Key, $Attribute, $DataType, $Description, $AllowedValues
    }

    $FileContent += $parameterSection
    return $FileContent
}

function Set-ResourceReadme {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ResourceFilePath,

        [Parameter(Mandatory = $false)]
        [string] $ReadMeFilePath = (Join-Path (Split-Path $ResourceFilePath -Parent) 'Help'),

        [Parameter(Mandatory = $false)]
        [ValidateSet(
            'Parameters'
        )]
        [string[]] $SectionsToRefresh = @(
            'Parameters'
        )
    )

    # Check resource file Path
    $ResourceFilePath = Resolve-Path -Path $ResourceFilePath -ErrorAction Stop

    if (-not (Test-Path $ResourceFilePath -PathType 'Leaf')) {
        throw "[$ResourceFilePath] is no valid file path."
    }

    # Check the resources that are exported
    $moduleManifest = Import-PowerShellDataFile -Path ($ResourceFilePath.Replace('.psm1', '.psd1'))
    $moduleName = $moduleManifest.RootModule.Replace('.psm1', '')
    $resources = $moduleManifest.DscResourcesToExport
    $resources | ForEach-Object { Write-Verbose -Message ('Resource: {0}' -f $_) }

    # TODO: Grab manual notes if needed

    foreach ($resource in $resources) {
        $docFile = Join-Path -Path $ReadMeFilePath -ChildPath ('{0}.md' -f $resource)

        $resourceInstance = Get-TypeInstanceFromModule -ModuleName $ResourceFilePath -ClassName $resource
        $dscResourceInstance = $resourceInstance::new()
        $t = $dscResourceInstance.GetType()

        $resourceInfoMethod = $t.GetMethod('GetResourceInfo')
        if ($null -eq $resourceInfoMethod) {
            Write-Warning -Message ('Resource [{0}] does not have a GetResourceInfo method.' -f $resource)
            continue
        }

        $resourceInfo = $resourceInfoMethod.Invoke($null, $null)

        $resourcePropertyInfoMethod = $t.GetMethod('GetResourcePropertyInfo')
        if ($null -eq $resourcePropertyInfoMethod) {
            Write-Warning -Message ('Resource [{0}] does not have a GetResourcePropertyInfo method.' -f $resource)
            continue
        }

        $resourcePropertyInfo = $resourcePropertyInfoMethod.Invoke($null, $null)

        # Initialize the resource file
        $inputObject = @{
            ModuleName   = $moduleName
            ResourceName = $resource
            Synopsis     = $resourceInfo.Description
            Description  = $resourceInfo.Description
        }
        $fileContent = Initialize-ResourceFile @inputObject

        # =============== #
        #   Set content   #
        # =============== #

        if ($SectionsToRefresh -contains 'Parameters') {
            $fileContent = Set-ResourcePropertyParameters -ParameterFileContent $resourcePropertyInfo -FileContent $fileContent
        }

        return $fileContent

        # $commandHelper = [Microsoft.PowerShell.PlatyPS.Model.CommandHelp]::new()
        # $commandHelper.Title = $resource
        # $commandHelper.Synopsis = $resourceInfo.Description
        # $commandHelper.Description = ($resourceInfo.Description + "`n`n## PARAMETERS`n`n" + ($parameterSection -join "`n"))
        # $commandHelper.Metadata = [ordered]@{
        #     'external help file' = ('{0}-Help.xml' -f $moduleManifest.RootModule)
        #     'Module Name'        = 'test'
        #     'ms.date'            = (Get-Date).ToString('MM/dd/yyyy')
        #     'online version'     = $null
        #     schema               = '2.0.0'
        #     title                = $resource
        # }
    }
}
