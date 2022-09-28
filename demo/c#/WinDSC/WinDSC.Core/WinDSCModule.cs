namespace WinDSC.Core
{
    using System.Management.Automation;
    using System.Management.Automation.Runspaces;
    using System.Reflection;
    using System.Text;
    using Constants;
    using Microsoft.PowerShell;
    using WinDSC.Core.Helpers;

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

        public PSStreamOutputHelper InvokeWinDSCResource(string filePath)
        {
            if (!File.Exists(filePath))
            {
                throw new FileNotFoundException(filePath);
            }

            this.powerShell.AddCommand("Start-WinDSC")
                .AddParameter("inputFile", filePath)
                .Invoke();

            PSStreamOutputHelper psStreamOutput = new(this.powerShell);

            return psStreamOutput;
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
    }
}

