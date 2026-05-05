using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using HomeForge.Core;

namespace HomeForge.App.Views;

public partial class LogsView : UserControl
{
    public LogsView()
    {
        InitializeComponent();
    }

    private static void OpenFolder(string path)
    {
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
    }

    private void OpenLogs_Click(object sender, RoutedEventArgs e) => OpenFolder(HomeForgePaths.Logs);
    private void OpenReports_Click(object sender, RoutedEventArgs e) => OpenFolder(HomeForgePaths.Reports);
    private void OpenConnections_Click(object sender, RoutedEventArgs e) => OpenFolder(HomeForgePaths.AppConnections);
}
