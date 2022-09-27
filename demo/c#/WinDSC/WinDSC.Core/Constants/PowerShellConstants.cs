using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WinDSC.Core.Constants
{
    internal static class PowerShellConstants
    {
        public const string PowerShellPath = "PowerShell";
        public const string ModulesPath = "Modules";
        public const string PSModulePath = "PSModulePath";

        internal static class Arguments
        {
            public const string Unrestricted = "Unrestricted";
        }

        internal static class Commands
        {
            public const string SetExecutionPolicy = "Set-ExecutionPolicy";
            public const string InvokeDscResource = "Invoke-DscResource";
        }

        internal static class DscResourceMethods
        {
            public const string Set = "Set";
            public const string Get = "Get";
            public const string Test = "Test";
        }

        internal static class Modules
        {
            public const string WinDSCResourceDemo = "WinDSCResourceDemo";
        }

        internal static class Parameters
        {
            public const string Force = "Force";
            public const string Name = "Name";
            public const string ModuleName = "ModuleName";
            public const string Method = "Method";
            public const string Property = "Property";
        }
    }
}
