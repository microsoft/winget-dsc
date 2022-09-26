using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Reflection;
using System.Text;
using System.Text.Json;
using WinDSCDemo.Helpers;

try
{
    //DemoWithScript();
    DemoWithCommand();
}
catch (Exception e)
{
    Console.WriteLine(e);
}

// Add custom module path to PSModulePath.
// Sets execution policies to unrestricted.
// Reads json input file.
// Calls Invoke-DscResource per package.
// This fails with the same  Cannot find type [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo] error
// if Helpers\DscResourceInfo.cs is not compiled.
static void DemoWithCommand()
{
    string psModulePathEnv = "PSModulePath";
    var powerShellModulePath = GetPowerShellCustomModulePath();

    var psModulePathEnvValue = Environment.GetEnvironmentVariable(psModulePathEnv);
    if (psModulePathEnvValue is null)
    {
        Environment.SetEnvironmentVariable(psModulePathEnv, powerShellModulePath);
    }
    else if (!psModulePathEnvValue.Contains(powerShellModulePath))
    {
        psModulePathEnvValue += $";{powerShellModulePath}";
        Environment.SetEnvironmentVariable(psModulePathEnv, psModulePathEnvValue);
    }

    VerifyFiles();

    PowerShell powerShell = PowerShell.Create();

    powerShell.AddCommand("Set-ExecutionPolicy")
       .AddArgument("Unrestricted")
       .AddParameter("Force")
       .Invoke();

    ClearStreamAndStopIfError(powerShell);

    var packagesFile = GetPackagesFile();
    foreach (var package in packagesFile.Packages)
    {
        var properties = package.GetProperties();
        var response = powerShell.AddCommand("Invoke-DscResource")
                  .AddParameter("Name", "WinDSCResourceDemo")
                  .AddParameter("ModuleName", "WinDSCResourceDemo")
                  .AddParameter("Method", "Set")
                  .AddParameter("Property", properties)
                  .Invoke();
    }
}

// Adds custom module path to PSModulePath.
// Sets execution policies to unrestricted.
// Runs PowerShell\demo.ps1
// Fails:
// System.Management.Automation.RuntimeException: Cannot find type [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]: verify that the assembly containing this type is loaded.
//  ---> System.Management.Automation.PSArgumentException: Cannot find type [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]: verify that the assembly containing this type is loaded.
//    at System.Management.Automation.MshCommandRuntime.ThrowTerminatingError(ErrorRecord errorRecord)
//    ---End of inner exception stack trace ---
//    at System.Management.Automation.Runspaces.PipelineBase.Invoke(IEnumerable input)
//    at System.Management.Automation.PowerShell.Worker.ConstructPipelineAndDoWork(Runspace rs, Boolean performSyncInvoke)
//    at System.Management.Automation.PowerShell.Worker.CreateRunspaceIfNeededAndDoWork(Runspace rsToUse, Boolean isSync)
//    at System.Management.Automation.PowerShell.CoreInvokeHelper[TInput, TOutput] (PSDataCollection`1 input, PSDataCollection`1 output, PSInvocationSettings settings)
//    at System.Management.Automation.PowerShell.CoreInvoke[TInput, TOutput] (PSDataCollection`1 input, PSDataCollection`1 output, PSInvocationSettings settings)
//    at System.Management.Automation.PowerShell.Invoke()
//    at Program.<Main>$(String[] args) in C:\Dev\windsc\demo\c#\WinDSC\WinDSCDemo\Program.cs:line 73
static void DemoWithScript()
{
    string psModulePathEnv = "PSModulePath";
    var powerShellModulePath = GetPowerShellCustomModulePath();

    var psModulePathEnvValue = Environment.GetEnvironmentVariable(psModulePathEnv);
    if (psModulePathEnvValue is null)
    {
        Environment.SetEnvironmentVariable(psModulePathEnv, powerShellModulePath);
    }
    else if (!psModulePathEnvValue.Contains(powerShellModulePath))
    {
        psModulePathEnvValue += $";{powerShellModulePath}";
        Environment.SetEnvironmentVariable(psModulePathEnv, psModulePathEnvValue);
    }

    VerifyFiles();

    PowerShell powerShell = PowerShell.Create();

    powerShell.AddCommand("Set-ExecutionPolicy")
       .AddArgument("Unrestricted")
       .AddParameter("Force")
       .Invoke();

    ClearStreamAndStopIfError(powerShell);

    powerShell.AddScript(@"PowerShell\demo.ps1")
        .Invoke();

    ClearStreamAndStopIfError(powerShell);
}

static string? GetExecutionPath()
{
    return Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
}

static string GetPowerShellPath()
{
    var exePath = GetExecutionPath();
    if (!string.IsNullOrEmpty(exePath))
    {
        return Path.Combine(exePath, "PowerShell");
    }

    return "PowerShell";
}

static string GetPowerShellCustomModulePath()
{
    return Path.Combine(GetPowerShellPath(), "Modules");
}

static void VerifyFiles()
{
    var powerShellPath = GetPowerShellPath();
    var powerShellModulePath = GetPowerShellCustomModulePath();
    var files = new List<string>()
    {
        $"{powerShellModulePath}\\WinDSCResourceDemo\\WinDSCResourceDemo.psd1",
        $"{powerShellModulePath}\\WinDSCResourceDemo\\WinDSCResourceDemo.psm1",
        $"{powerShellModulePath}\\DscResourceInfo\\DscResourceInfo.psm1",
        $"{powerShellPath}\\input.json",

    };

    foreach (var file in files)
    {
        if (!File.Exists(file))
        {
            throw new FileNotFoundException(file);
        }
    }
}

static PackagesFile GetPackagesFile()
{
    string fileName = $"{GetPowerShellPath()}\\input.json";
    string jsonString = File.ReadAllText(fileName);
    return JsonSerializer.Deserialize<PackagesFile>(
        jsonString,
        new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
}

static void PrintProperties(Collection<PSObject> objs)
{
    foreach (var psObj in objs)
    {
        foreach (var property in psObj.Properties)
        {
            try
            {
                Console.WriteLine($"{property.Name}: '{property.Value}'");
            }
            catch (GetValueInvocationException e)
            {
                Console.WriteLine($"Failed getting value of {property.Name}. {e}");
            }
        }
    }
}

static void ClearStreamAndStopIfError(PowerShell ps)
{
    var verboseMessageBuilder = new StringBuilder();
    foreach (var info in ps.Streams.Verbose)
    {
        verboseMessageBuilder.AppendLine(info.ToString());
    }

    var verboseMessage = verboseMessageBuilder.ToString();
    if (!string.IsNullOrEmpty(verboseMessage))
    {
        Console.WriteLine("Verbose message:");
        Console.WriteLine(verboseMessage);
    }

    var infoMessageBuilder = new StringBuilder();
    foreach (var info in ps.Streams.Information)
    {
        infoMessageBuilder.AppendLine(info.ToString());
    }

    var infoMessage = infoMessageBuilder.ToString();
    if (!string.IsNullOrEmpty(infoMessage))
    {
        Console.WriteLine("Info message:");
        Console.WriteLine(infoMessage);
    }

    if (ps.HadErrors)
    {
        var message = new StringBuilder();
        foreach (var err in ps.Streams.Error)
        {
            message.AppendLine(err.ToString());
        }

        throw new Exception($"Error message\n{message}");
    }

    ps.Streams.ClearStreams();
}
