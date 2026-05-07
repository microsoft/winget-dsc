// Hello-world probe for the WinUI 3 flow.
//
// We don't show a window (CI runners are headless for interactive UI), but we
// *do* reference a WinUI type and read back its name — this forces the
// Microsoft.WinUI projection assembly (shipped by the Microsoft.WindowsAppSDK
// NuGet) to actually load. If the WinAppSDK restore was incomplete, the
// `typeof` below would fail and the harness would flag the flow broken.

using System;

var name = typeof(Microsoft.UI.Xaml.Application).Name;
Console.WriteLine($"WinUI: {name}");
