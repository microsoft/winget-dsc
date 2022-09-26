using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WinDSCDemo.Helpers
{
    public class Package
    {
        public string PackageIdentifier { get; set; }

        public string Version { get; set; }

        public Dictionary<string, string> GetProperties()
        {
            return new Dictionary<string, string>()
            {
                {nameof(PackageIdentifier), this.PackageIdentifier},
                {nameof(Version), this.Version},
            };
        }
    }
}
