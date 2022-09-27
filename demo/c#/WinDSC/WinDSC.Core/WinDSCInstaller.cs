namespace WinDSC.Core
{
    using System.Management.Automation;
    using System.Reflection;
    using System.Text;
    using System.Text.Json;
    using Constants;
    using Model;

    public class WinDSCInstaller : IDisposable
    {
        private bool disposed = false;

        private readonly PowerShell powerShell;

        public WinDSCInstaller()
        {
            this.SetModulePath();

            this.powerShell = PowerShell.Create();

            this.powerShell.AddCommand(PowerShellConstants.Commands.SetExecutionPolicy)
               .AddArgument(PowerShellConstants.Arguments.Unrestricted)
               .AddParameter(PowerShellConstants.Parameters.Force)
               .Invoke();
            this.ClearStreamAndStopIfError();

        }

        ~WinDSCInstaller() => Dispose(false);

        public void InvokeWinDSCResource(string filePath)
        {
            if (!File.Exists(filePath))
            {
                throw new FileNotFoundException(filePath);
            }

            string jsonString = File.ReadAllText(filePath);
            var packagesFile = JsonSerializer.Deserialize<PackagesFile>(
                jsonString,
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                    
                });

            if (packagesFile is not null)
            {
                this.InvokeWinDSCResource((PackagesFile)packagesFile);
            }
            else
            {
                throw new ArgumentException();
            }
        }

        public void InvokeWinDSCResource(PackagesFile packagesFile)
        {
            foreach (var package in packagesFile.Packages)
            {
                Console.WriteLine(package.PackageIdentifier + " " + package.Version);
                _ = this.powerShell.AddCommand(PowerShellConstants.Commands.InvokeDscResource)
                    .AddParameter(
                        PowerShellConstants.Parameters.Name,
                        PowerShellConstants.Modules.WinDSCResourceDemo)
                    .AddParameter(
                        PowerShellConstants.Parameters.ModuleName,
                        PowerShellConstants.Modules.WinDSCResourceDemo)
                    .AddParameter(
                        PowerShellConstants.Parameters.Method,
                        PowerShellConstants.DscResourceMethods.Set)
                    .AddParameter(
                        PowerShellConstants.Parameters.Property,
                        package.GetProperties())
                    .Invoke();
            }
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
                }

                disposed = true;
            }
        }

        private void SetModulePath()
        {
            string psModulePathEnv = PowerShellConstants.PSModulePath;
            var powerShellModulePath = this.GetPowerShellCustomModulePath();

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

                throw new Exception($"Error message\n{message}");
            }

            this.powerShell.Streams.ClearStreams();
        }
    }
}
