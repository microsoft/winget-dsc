namespace WinDSC.Core.Model
{
    using System.Text.Json.Serialization;

    public class Package : IJsonOnDeserialized, IJsonOnSerializing
    {
        public string PackageIdentifier { get; set; } = string.Empty;

        public string Version { get; set; } = string.Empty;

        public Dictionary<string, string> GetProperties()
        {
            return new Dictionary<string, string>()
            {
                {nameof(PackageIdentifier), this.PackageIdentifier},
                {nameof(Version), this.Version},
            };
        }

        void IJsonOnDeserialized.OnDeserialized()
        {
            Validate();
        }

        void IJsonOnSerializing.OnSerializing()
        {
            Validate();
        }

        private void Validate()
        {
            if (string.IsNullOrEmpty(this.PackageIdentifier))
            {
                throw new ArgumentNullException(nameof(this.PackageIdentifier));
            }

            if (string.IsNullOrEmpty(this.Version))
            {
                throw new ArgumentNullException(nameof(this.Version));
            }
        }
    }
}
