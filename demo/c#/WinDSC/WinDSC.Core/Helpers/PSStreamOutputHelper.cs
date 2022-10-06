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

        public void PrintAll()
        {
            if (!string.IsNullOrEmpty(this.Verbose))
            {
                Console.WriteLine("Verbose:");
                Console.WriteLine(this.Verbose);
            }

            if (!string.IsNullOrEmpty(this.Information))
            {
                Console.WriteLine("Information:");
                Console.WriteLine(this.Information);
            }

            if (!string.IsNullOrEmpty(this.Progress))
            {
                Console.WriteLine("Progress:");
                Console.WriteLine(this.Progress);
            }

            if (!string.IsNullOrEmpty(this.Warning))
            {
                Console.WriteLine("Warning:");
                Console.WriteLine(this.Warning);
            }

            if (!string.IsNullOrEmpty(this.Error))
            {
                Console.WriteLine("Error:");
                Console.WriteLine(this.Error);
            }
        }
    }
}
