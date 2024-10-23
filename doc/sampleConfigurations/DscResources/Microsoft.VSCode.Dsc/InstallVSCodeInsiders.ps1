configuration InstallVSCodeInsiders
{
    Import-DscResource -ModuleName 'Microsoft.VSCode.Dsc'

    Node localhost
    {
        VSCodeInsiders InstallVSCodeInsiders
        {
            Insiders = $true 
        }
    }
}