﻿using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Text;

try
{
    string psModulePathEnv = "PSModulePath";
    var powerShellPath = GetPowerShellPath();

    var psModulePathEnvValue = Environment.GetEnvironmentVariable(psModulePathEnv);
    if (psModulePathEnvValue is null)
    {
        Environment.SetEnvironmentVariable(psModulePathEnv, powerShellPath);
    }
    else if (!psModulePathEnvValue.Contains(powerShellPath))
    {
        psModulePathEnvValue += $";{powerShellPath}";
        Environment.SetEnvironmentVariable(psModulePathEnv, psModulePathEnvValue);
    }

    //VerifyLoadedAssemblies();
    VerifyFiles();

    var initialSessionState = InitialSessionState.CreateDefault();

    // Here import our future module
    var modules = GetModulesToLoad();
    //initialSessionState.ImportPSModule(modules.ToArray());
    var runspace = RunspaceFactory.CreateRunspace(initialSessionState);
    runspace.Open();

    PowerShell powerShell = PowerShell.Create();
    powerShell.Runspace = runspace;

    powerShell.AddCommand("Set-ExecutionPolicy")
       .AddArgument("Unrestricted")
       .AddParameter("Force")
       .Invoke();

    ClearStreamAndStopIfError(powerShell);

    ////powerShell.AddScript(@"PowerShell\helpers\DscResourceInfo.ps1")
    ////    .Invoke();
    ////
    ////ClearStreamAndStopIfError(powerShell);

    ////powerShell.AddCommand(@"Import-Module")
    ////    .AddParameter("Name", "DscResourceInfo")
    ////    .Invoke();

    ClearStreamAndStopIfError(powerShell);

    var properties = new Dictionary<string, string>()
    {
        {"PackageId", "test.test"},
        {"Version", "1.0"},
    };

    // Without editing PSModulePath
    // System.Management.Automation.RuntimeException: unexpected state - no
    // resources found - get-dscresource should have thrown without adding the module path
    //
    // Adding the module path.
    // System.Management.Automation.RuntimeException: Cannot find type
    // Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]: verify
    // that the assembly containing this type is loaded.
    var response = powerShell.AddCommand("Invoke-DscResource")
              .AddParameter("Name", "WinDSCResourceDemo")
              .AddParameter("ModuleName", "WinDSCResourceDemo")
              .AddParameter("Method", "Set")
              .AddParameter("Property", properties)
              .Invoke();

    // System.Management.Automation.RuntimeException: Cannot find type
    // Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]: verify
    // that the assembly containing this type is loaded.
    ////powerShell.AddScript(@"PowerShell\demo.ps1")
    ////    .Invoke();

    ClearStreamAndStopIfError(powerShell);
}
catch (Exception e)
{
    Console.WriteLine(e);
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

static IReadOnlyList<string> GetModulesToLoad()
{
    var powerShellPath = GetPowerShellPath();
    var modules = new List<string>()
    {
        $"{powerShellPath}DscResourceInfo.psm1",
    };

    return modules;
}

static void VerifyFiles()
{
    var powerShellPath = GetPowerShellPath();
    var files = new List<string>()
    {
        $"{powerShellPath}\\WinDSCResourceDemo\\WinDSCResourceDemo.psd1",
        $"{powerShellPath}\\WinDSCResourceDemo\\WinDSCResourceDemo.psm1",
        $"{powerShellPath}\\addToModulePath.ps1",
        $"{powerShellPath}\\demo.ps1",
        $"{powerShellPath}\\DscResourceInfo.psm1",
        $"{powerShellPath}\\helpers\\DscResourceInfo.ps1"
    };

    foreach (var file in files)
    {
        if (!File.Exists(file))
        {
            throw new FileNotFoundException(file);
        }
    }
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

static void VerifyLoadedAssemblies()
{
    foreach (var assemblyName in Assembly.GetExecutingAssembly().GetReferencedAssemblies())
    {
        if (assemblyName.Name == "System.Management.Automation")
        {
            Console.WriteLine($"{assemblyName} is loaded");

            var assembly = Assembly.Load(assemblyName.ToString());
            Console.WriteLine($"Location: {assembly.Location}");

            // $asm.GetTypes() | select Name, Namespace | sort Namespace | ft -groupby Namespace

            foreach (var type in assembly.GetTypes())
            {
                if (type.Namespace == "System.Management.Automation" &&
                    type.Name == "DscResourceInfo")
                {
                    Console.WriteLine("Found System.Management.Automation.DscResourceInfo");
                }
            }
        }
    }
}
