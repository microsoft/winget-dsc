using Microsoft.UI.Xaml;
using System;
using Windows.Storage;
using Windows.Storage.Pickers;
using WinDSC.Core;
using WinRT.Interop;

// To learn more about WinUI, the WinUI project structure,
// and more about our project templates, see: http://aka.ms/winui-project-info.

namespace PackagedDemo
{
    /// <summary>
    /// An empty window that can be used on its own or navigated to within a Frame.
    /// </summary>
    public sealed partial class MainWindow : Window
    {
        public MainWindow()
        {
            this.InitializeComponent();
        }

        private async void myButton_Click(object sender, RoutedEventArgs e)
        {
            FileOpenPicker openPicker = new()
            {
                ViewMode = PickerViewMode.List,
                SuggestedStartLocation = PickerLocationId.DocumentsLibrary
            };
            openPicker.FileTypeFilter.Add(".json");

            var hwnd = WindowNative.GetWindowHandle(this);
            InitializeWithWindow.Initialize(openPicker, hwnd);

            StorageFile file = await openPicker.PickSingleFileAsync();
            if (file is not null)
            {
                using WinDSCModule winDSCModule = new();
                var psStreamOutputHelper = winDSCModule.InvokeWinDSCResource(file.Path);

                psOutput.Text = "Done";
                if (psStreamOutputHelper.HadErrors)
                {
                    psOutput.Text += Environment.NewLine + psStreamOutputHelper.Error;
                }
            }
        }
    }
}
