// Hello-world probe for the WinForms flow.
//
// We don't show a window (CI runners are headless for interactive UI), but we
// *do* construct a WinForms control and read back its properties — this forces
// the Windows Forms assemblies and the Windows Desktop runtime to actually
// load. If the .NET SDK install was incomplete (e.g. missing Desktop targeting
// pack), the `new Form()` call below would fail at runtime and the harness
// would flag the flow broken.

using System;
using System.Windows.Forms;

using var form = new Form { Text = "hello-winforms" };
Console.WriteLine($"WinForms: {form.Text}");
