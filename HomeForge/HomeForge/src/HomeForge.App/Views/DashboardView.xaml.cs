using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using HomeForge.Core;
using HomeForge.Services;

namespace HomeForge.App.Views;

public partial class DashboardView : UserControl
{
    private readonly SystemStatusService _statusService;
    private readonly FolderSetupService _folderSetupService;

    public DashboardView(SystemStatusService statusService, FolderSetupService folderSetupService)
    {
        InitializeComponent();
        _statusService = statusService;
        _folderSetupService = folderSetupService;
        Refresh();
    }

    private void Refresh()
    {
        var s = _statusService.GetSnapshot();
        ServerNameText.Text = s.ComputerName;
        AdminText.Text = s.IsAdministrator ? "Admin access" : "Standard access";
        IpText.Text = s.LocalIpAddress;
        DockerBadgeText.Text = s.DockerDetected ? "Docker ready" : "Docker missing";
        TailscaleBadgeText.Text = s.TailscaleDetected ? "Tailscale ready" : "Tailscale missing";
        RootStatusText.Text = s.RootExists ? "Ready" : "Not prepared";
        AppFoldersText.Text = s.DesktopAppFolderCount.ToString();
        ApprovedAppsText.Text = s.ApprovedDesktopAppCount.ToString();
        LastUpdatedText.Text = s.CapturedAt.ToString("dd/MM/yyyy HH:mm");

        NextStepText.Text = s.RootExists
            ? "Create a connection profile or add your first hosted application."
            : "Prepare the server folder structure before adding applications.";
    }

    private void Refresh_Click(object sender, RoutedEventArgs e) => Refresh();

    private void CreateFolders_Click(object sender, RoutedEventArgs e)
    {
        _folderSetupService.CreateFolderLayout();
        Refresh();
        MessageBox.Show("HomeForge folders were created or repaired.", "HomeForge", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void OpenRoot_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(HomeForgePaths.RootPath);
        Process.Start(new ProcessStartInfo(HomeForgePaths.RootPath) { UseShellExecute = true });
    }
}
