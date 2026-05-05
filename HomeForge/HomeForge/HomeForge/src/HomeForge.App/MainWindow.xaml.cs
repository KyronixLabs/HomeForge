using System.Windows;
using System.Windows.Controls;
using HomeForge.App.Views;
using HomeForge.Services;

namespace HomeForge.App;

public partial class MainWindow : Window
{
    private readonly NetworkService _networkService = new();
    private readonly CommandService _commandService = new();
    private readonly FolderSetupService _folderSetupService = new();
    private readonly DesktopAppService _desktopAppService = new();

    private readonly SystemStatusService _statusService;
    private readonly AppConnectionService _appConnectionService;
    private readonly ServerSetupService _serverSetupService;

    public MainWindow()
    {
        InitializeComponent();
        _statusService = new SystemStatusService(_networkService, _commandService);
        _appConnectionService = new AppConnectionService(_networkService);
        _serverSetupService = new ServerSetupService(_folderSetupService, _networkService, _commandService);
        ShowPage("Dashboard");
    }

    private void Nav_Checked(object sender, RoutedEventArgs e)
    {
        if (sender is RadioButton rb && rb.Tag is string tag)
        {
            ShowPage(tag);
        }
    }

    private void ShowPage(string tag)
    {
        switch (tag)
        {
            case "Connections":
                PageTitle.Text = "Connections";
                PageSubtitle.Text = "Create connection details for local or public access.";
                MainContent.Content = new AppConnectionsView(_appConnectionService);
                break;
            case "DesktopApps":
                PageTitle.Text = "Apps";
                PageSubtitle.Text = "Manage application folders and launch preparation.";
                MainContent.Content = new DesktopAppsView(_desktopAppService);
                break;
            case "Tools":
                PageTitle.Text = "Setup";
                PageSubtitle.Text = "Prepare, maintain and secure this Windows server.";
                MainContent.Content = new ToolsView(_folderSetupService, _commandService, _serverSetupService);
                break;
            case "Backups":
                PageTitle.Text = "Backups";
                PageSubtitle.Text = "Prepare backup and recovery locations.";
                MainContent.Content = new BackupsView(_folderSetupService);
                break;
            case "Security":
                PageTitle.Text = "Security";
                PageSubtitle.Text = "Keep public access focused on your API only.";
                MainContent.Content = new SecurityView();
                break;
            case "Logs":
                PageTitle.Text = "Logs";
                PageSubtitle.Text = "Review reports, logs and connection records.";
                MainContent.Content = new LogsView();
                break;
            default:
                PageTitle.Text = "Dashboard";
                PageSubtitle.Text = "Server overview and readiness.";
                MainContent.Content = new DashboardView(_statusService, _folderSetupService);
                break;
        }
    }
}
