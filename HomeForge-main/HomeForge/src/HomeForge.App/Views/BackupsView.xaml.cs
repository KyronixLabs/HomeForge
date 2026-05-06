using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using HomeForge.Core;
using HomeForge.Services;

namespace HomeForge.App.Views;

public partial class BackupsView : UserControl
{
    private readonly FolderSetupService _folderSetupService;

    public BackupsView(FolderSetupService folderSetupService)
    {
        InitializeComponent();
        _folderSetupService = folderSetupService;
    }

    private void CreateFolders_Click(object sender, RoutedEventArgs e)
    {
        _folderSetupService.CreateFolderLayout();
        MessageBox.Show("Backup and restore folders are ready.", "HomeForge", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void OpenBackups_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(HomeForgePaths.Backups);
        Process.Start(new ProcessStartInfo(HomeForgePaths.Backups) { UseShellExecute = true });
    }

    private void OpenRestore_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(HomeForgePaths.Restore);
        Process.Start(new ProcessStartInfo(HomeForgePaths.Restore) { UseShellExecute = true });
    }
}
