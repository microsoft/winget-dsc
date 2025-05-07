@{
    <#
        This is only required if you need to use the method PowerShellGet & PSDepend
        It is not required for PSResourceGet or ModuleFast (and will be ignored).
        See Resolve-Dependency.psd1 on how to enable methods.
    #>
    #PSDependOptions             = @{
    #    AddToPath  = $true
    #    Target     = 'output\RequiredModules'
    #    Parameters = @{
    #        Repository = 'PSGallery'
    #    }
    #}

    InvokeBuild                 = '5.12.2'
    PSScriptAnalyzer            = '1.24.0'
    Pester                      = '5.7.1'
    ModuleBuilder               = '3.1.7'
    ChangelogManagement         = '3.1.0'
    Sampler                     = '0.118.2'
    'Sampler.GitHubTasks'       = '0.3.4'
    'DscResource.Base'          = '1.3.0'
    'DscResource.Common'        = '0.21.0'
    'DscResource.Test'          = '0.17.2'
    'DscResource.AnalyzerRules' = '0.2.0'
    xDscResourceDesigner        = '1.13.0.0'
    'DscResource.DocGenerator'  = '0.13.0'
    PSDesiredStateConfiguration = '2.0.7'
}

