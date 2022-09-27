namespace WinDSC.Core.Model
{
    using System.Text.Json.Serialization;

    public class PackagesFile : IJsonOnDeserialized, IJsonOnSerializing
    {
        public List<Package> Packages { get; set; } = new List<Package>();

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
            if (this.Packages is null)
            {
                throw new ArgumentNullException(nameof(this.Packages));
            }
        }
    }
}
