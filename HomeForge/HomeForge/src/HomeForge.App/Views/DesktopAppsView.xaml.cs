using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using HomeForge.Services;

namespace HomeForge.App.Views;

public partial class DesktopAppsView : UserControl
{
    private readonly DesktopAppService _service;

    public DesktopAppsView(DesktopAppService service)
    {
        InitializeComponent();
        _service = service;
        Refresh();
    }

    private void Refresh()
    {
        FolderText.Text = _service.EnsureDropZone();
        AppsGrid.ItemsSource = _service.ScanDropZone();
    }

    private void OpenDropZone_Click(object sender, RoutedEventArgs e)
    {
        var path = _service.EnsureDropZone();
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
        Refresh();
    }

    private void Scan_Click(object sender, RoutedEventArgs e) => Refresh();
}
