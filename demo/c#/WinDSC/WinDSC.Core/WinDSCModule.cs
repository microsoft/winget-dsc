namespace WinDSC.Core
{
    using System.Management.Automation;
    using System.Management.Automation.Runspaces;
    using System.Reflection;
    using System.Text;
    using System.Text.Json;
    using Constants;
    using Microsoft.PowerShell;
    using Model;

    public class WinDSCModule : IDisposable
    {
        private bool disposed = false;

        private readonly PowerShell powerShell;
        private readonly Runspace runspace;

        public WinDSCModule()
        {
            var winDscModulePath = Path.Combine(GetPowerShellCustomModulePath(), "WinDSC", "WinDSC.psm1");

            InitialSessionState initialSessionState = InitialSessionState.CreateDefault();
            initialSessionState.ExecutionPolicy = ExecutionPolicy.Unrestricted;
            initialSessionState.ImportPSModule(new string[]
            {
                winDscModulePath,
            });
            this.runspace = RunspaceFactory.CreateRunspace(initialSessionState);
            this.runspace.Open();

            this.powerShell = PowerShell.Create(this.runspace);
        }

        ~WinDSCModule() => Dispose(false);

        public void InvokeWinDSCResource(string filePath)
        {
            if (!File.Exists(filePath))
            {
                throw new FileNotFoundException(filePath);
            }

            this.powerShell.AddCommand("Start-WinDSC")
                .AddParameter("inputFile", filePath)
                .Invoke();

            this.ClearStreamAndStopIfError();
        }

        // Public implementation of Dispose pattern callable by consumers.
        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        // Protected implementation of Dispose pattern.
        protected virtual void Dispose(bool disposing)
        {
            if (!disposed)
            {
                if (disposing)
                {
                    this.powerShell.Dispose();
                    this.runspace.Dispose();
                }

                disposed = true;
            }
        }

        private string? GetExecutionPath()
        {
            return Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        }

        private string GetPowerShellPath()
        {
            var exePath = this.GetExecutionPath();
            if (!string.IsNullOrEmpty(exePath))
            {
                return Path.Combine(exePath, PowerShellConstants.PowerShellPath);
            }

            return PowerShellConstants.PowerShellPath;
        }

        private string GetPowerShellCustomModulePath()
        {
            return Path.Combine(this.GetPowerShellPath(), PowerShellConstants.ModulesPath);
        }

        private void ClearStreamAndStopIfError()
        {
            // TODO: don't print and add to logs.
            var verboseMessageBuilder = new StringBuilder();
            foreach (var info in this.powerShell.Streams.Verbose)
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
            foreach (var info in this.powerShell.Streams.Information)
            {
                infoMessageBuilder.AppendLine(info.ToString());
            }

            var infoMessage = infoMessageBuilder.ToString();
            if (!string.IsNullOrEmpty(infoMessage))
            {
                Console.WriteLine("Info message:");
                Console.WriteLine(infoMessage);
            }

            if (this.powerShell.HadErrors)
            {
                var message = new StringBuilder();
                foreach (var err in this.powerShell.Streams.Error)
                {
                    message.AppendLine(err.ToString());
                }

                Console.WriteLine(message.ToString());
            }

            this.powerShell.Streams.ClearStreams();
        }
    }
}

