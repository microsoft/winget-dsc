namespace WinDSC.Core.Helpers
{
    using System.Management.Automation;
    using System.Text;

    public class PSStreamOutputHelper
    {
        public PSStreamOutputHelper(PowerShell powerShell)
        {
            if (powerShell.Streams.Verbose.Any())
            {
                var psStreamBuilder = new StringBuilder();
                foreach (var line in powerShell.Streams.Verbose)
                {
                    psStreamBuilder.AppendLine($"\t{line}");
                }
                this.Verbose =  psStreamBuilder.ToString();
            }

            if (powerShell.Streams.Information.Any())
            {
                var psStreamBuilder = new StringBuilder();
                foreach (var line in powerShell.Streams.Information)
                {
                    psStreamBuilder.AppendLine($"\t{line}");
                }
                this.Information = psStreamBuilder.ToString();
            }

            if (powerShell.Streams.Progress.Any())
            {
                var psStreamBuilder = new StringBuilder();
                foreach (var line in powerShell.Streams.Progress)
                {
                    psStreamBuilder.AppendLine($"\t{line}");
                }
                this.Progress = psStreamBuilder.ToString();
            }

            if (powerShell.Streams.Warning.Any())
            {
                var psStreamBuilder = new StringBuilder();
                foreach (var line in powerShell.Streams.Warning)
                {
                    psStreamBuilder.AppendLine($"\t{line}");
                }
                this.Warning = psStreamBuilder.ToString();
            }

            this.HadErrors = powerShell.HadErrors;

            if (powerShell.Streams.Error.Any())
            {
                var psStreamBuilder = new StringBuilder();
                foreach (var line in powerShell.Streams.Error)
                {
                    psStreamBuilder.AppendLine($"\t{line}");
                }
                this.Error = psStreamBuilder.ToString();
            }

            powerShell.Streams.ClearStreams();
        }

        public string Verbose { get; private set; } = string.Empty;

        public string Information { get; private set; } = string.Empty;

        public string Progress { get; private set; } = string.Empty;


        public string Warning { get; private set; } = string.Empty;

        public string Error { get; private set; } = string.Empty;

        public bool HadErrors { get; private set; }
    }
}
