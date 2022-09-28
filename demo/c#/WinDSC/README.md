## WinDSC.Core
Core functionality. WinDSCModule.cs adds WinDSC module to the runspace and calls its function with the given input json file. WinDSCInstaller.cs is the same, but calls Invoke-DSCResource directly.

### DscResourceInfo.cs
This class is based on https://github.com/PowerShell/PSDesiredStateConfiguration/blob/master/src/PSDesiredStateConfiguration/helpers/DscResourceInfo.psm1
Without it, calling Invoke-DscResource will fail with
```
System.Management.Automation.RuntimeException: Cannot find type [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]: verify that the assembly containing this type is loaded.
  ---> System.Management.Automation.PSArgumentException: Cannot find type [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]: verify that the assembly containing this type is loaded.
    at System.Management.Automation.MshCommandRuntime.ThrowTerminatingError(ErrorRecord errorRecord)
    ---End of inner exception stack trace ---
    at System.Management.Automation.Runspaces.PipelineBase.Invoke(IEnumerable input)
    at System.Management.Automation.PowerShell.Worker.ConstructPipelineAndDoWork(Runspace rs, Boolean performSyncInvoke)
    at System.Management.Automation.PowerShell.Worker.CreateRunspaceIfNeededAndDoWork(Runspace rsToUse, Boolean isSync)
    at System.Management.Automation.PowerShell.CoreInvokeHelper[TInput, TOutput] (PSDataCollection`1 input, PSDataCollection`1 output, PSInvocationSettings settings)
    at System.Management.Automation.PowerShell.CoreInvoke[TInput, TOutput] (PSDataCollection`1 input, PSDataCollection`1 output, PSInvocationSettings settings)
    at System.Management.Automation.PowerShell.Invoke()
```

## PackagedDemo
PackagedDemo uses PowerShell Host in a package. It uses the same code as WinDSCDemo but it fails when the modules are not signed.

Error:
```
System.Management.Automation.CmdletInvocationException: AuthorizationManager check failed.
 ---> System.Management.Automation.PSSecurityException: AuthorizationManager check failed.
 ---> System.IO.FileNotFoundException: C:\Dev\windsc\demo\c#\WinDSC\PackagedDemo\bin\x64\Debug\net6.0-windows10.0.19041.0\win10-x64\AppX\Modules\PSDiagnostics\PSDiagnostics.psm1
   at System.Management.Automation.SignatureHelper.GetSignatureFromCatalog(String filename)
   at System.Management.Automation.SignatureHelper.GetSignatureFromCatalog(String filename)
   at System.Management.Automation.Internal.SecuritySupport.IsProductBinary(String file)
   at Microsoft.PowerShell.PSAuthorizationManager.CheckPolicy(ExternalScriptInfo script, PSHost host, Exception& reason)
   at Microsoft.PowerShell.PSAuthorizationManager.ShouldRun(CommandInfo commandInfo, CommandOrigin origin, PSHost host, Exception& reason)
   at System.Management.Automation.AuthorizationManager.ShouldRunInternal(CommandInfo commandInfo, CommandOrigin origin, PSHost host)
   --- End of inner exception stack trace ---
   at System.Management.Automation.AuthorizationManager.ShouldRunInternal(CommandInfo commandInfo, CommandOrigin origin, PSHost host)
   at Microsoft.PowerShell.Commands.ModuleCmdletBase.GetScriptInfoForFile(String fileName, String& scriptName, Boolean checkExecutionPolicy)
   at Microsoft.PowerShell.Commands.ModuleCmdletBase.LoadModule(PSModuleInfo parentModule, String fileName, String moduleBase, String prefix, SessionState ss, Object privateData, ImportModuleOptions& options, ManifestProcessingFlags manifestProcessingFlags, Boolean& found, Boolean& moduleFileFound)
   at Microsoft.PowerShell.Commands.ImportModuleCommand.ImportModule_LocallyViaName(ImportModuleOptions importModuleOptions, String name)
   at Microsoft.PowerShell.Commands.ImportModuleCommand.ProcessRecord()
   at System.Management.Automation.CommandProcessor.ProcessRecord()
   --- End of inner exception stack trace ---
   at System.Management.Automation.Runspaces.PipelineBase.Invoke(IEnumerable input)
   at System.Management.Automation.PowerShell.Worker.ConstructPipelineAndDoWork(Runspace rs, Boolean performSyncInvoke)
   at System.Management.Automation.PowerShell.Worker.CreateRunspaceIfNeededAndDoWork(Runspace rsToUse, Boolean isSync)
   at System.Management.Automation.PowerShell.CoreInvokeHelper[TInput,TOutput](PSDataCollection`1 input, PSDataCollection`1 output, PSInvocationSettings settings)
   at System.Management.Automation.PowerShell.CoreInvoke[TInput,TOutput](PSDataCollection`1 input, PSDataCollection`1 output, PSInvocationSettings settings)
   at System.Management.Automation.Runspaces.InitialSessionState.ProcessOneModule(Runspace initializedRunspace, String name, PSModuleInfo moduleInfoToLoad, String path, HashSet`1 publicCommands)
   at System.Management.Automation.Runspaces.InitialSessionState.ProcessModulesToImport(Runspace initializedRunspace, IEnumerable moduleList, String path, HashSet`1 publicCommands, HashSet`1 unresolvedCmdsToExpose)
   at System.Management.Automation.Runspaces.InitialSessionState.BindRunspace(Runspace initializedRunspace, PSTraceSource runspaceInitTracer)
   at System.Management.Automation.Runspaces.LocalRunspace.DoOpenHelper()
   at System.Management.Automation.Runspaces.RunspaceBase.CoreOpen(Boolean syncCall)
   at WinDSC.Core.W
```

To make it work:
1. Copy WinDSC.Core\PowerShell\Unsigned\*.psm1 to their respective directory in WinDSC.Core\PowerShell\Modules\ModuleName\ModuleName.psm1
2. Sign the modules wth a self-signed certificate. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_signing?view=powershell-7.2#create-a-self-signed-certificate
3. Once the cert is done move it to Trust Root Certificate authority.
4. In Visual Studio change the properties of the new signed files to "Copy if newer".
5. Run it in the packaged context.

An alternative to skip signing is to manually copy PSDiagnostics.psm1 but lets not do that. :)

## WinDSCDemo
Basically the same as PackagedDemo without running in the package context. Signing the modules is not required.

To make it work:
1. Copy WinDSC.Core\PowerShell\Unsigned\*.psm1 to their respective directory in WinDSC.Core\PowerShell\Modules\ModuleName\ModuleName.psm1
2. In Visual Studio change the properties of the new signed files to "Copy if newer".
3. Run it in the packaged context.
