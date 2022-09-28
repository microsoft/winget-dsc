using System.Reflection;
using WinDSC.Core;

try
{
    var inputFile = Path.Combine(
        Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location),
        "input.json");

    //using WinDSCInstaller winDscInstaller = new();
    //winDscInstaller.InvokeWinDSCResource(inputFile);

    using WinDSCModule winDscModule = new();
    winDscModule.InvokeWinDSCResource(inputFile);
}
catch (Exception e)
{
    Console.WriteLine(e);
}
