using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using HomeForge.Core;
using HomeForge.Services;

namespace HomeForge.App.Views;

public partial class ToolsView : UserControl
{
    private readonly FolderSetupService _folderSetupService;
    private readonly CommandService _commandService;
    private readonly ServerSetupService _serverSetupService;

    public ToolsView(FolderSetupService folderSetupService, CommandService commandService, ServerSetupService serverSetupService)
    {
        InitializeComponent();
        _folderSetupService = folderSetupService;
        _commandService = commandService;
        _serverSetupService = serverSetupService;
        OutputBox.Text = "Select an action. System-level changes require administrator access.";
    }


    private void SubTab_Checked(object sender, RoutedEventArgs e)
    {
        if (QuickToolsPanel is null || PcServerSetupPanel is null || InstallersPanel is null)
        {
            return;
        }

        QuickToolsPanel.Visibility = QuickToolsTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        PcServerSetupPanel.Visibility = PcServerSetupTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        InstallersPanel.Visibility = InstallersTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    private void ShowOutput(string title, Func<string> action)
    {
        try
        {
            OutputBox.Text = $"> {title}\r\n\r\nWorking...";
            OutputBox.Text = $"> {title}\r\n\r\n" + action();
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"> {title}\r\n\r\nFAILED\r\n{ex.Message}";
        }
    }

    private void CreateFolders_Click(object sender, RoutedEventArgs e) => ShowOutput("Create folder layout", _serverSetupService.CreateFolderLayout);
    private void RecommendedSetup_Click(object sender, RoutedEventArgs e) => ShowOutput("Run recommended server setup", _serverSetupService.RunRecommendedSetup);
    private void PowerSettings_Click(object sender, RoutedEventArgs e) => ShowOutput("Configure 24/7 power settings", _serverSetupService.ConfigureAlwaysOnPower);
    private void DeepPower_Click(object sender, RoutedEventArgs e) => ShowOutput("Improve power reliability", _serverSetupService.ConfigureDeepPowerOptimization);
    private void FirewallBaseline_Click(object sender, RoutedEventArgs e) => ShowOutput("Enable Windows Firewall baseline", _serverSetupService.ConfigureFirewallBaseline);
    private void NetworkPrivate_Click(object sender, RoutedEventArgs e) => ShowOutput("Set network profile to Private", _serverSetupService.ConfigureNetworkPrivate);
    private void UpdateHours_Click(object sender, RoutedEventArgs e) => ShowOutput("Set Windows Update active hours", _serverSetupService.ConfigureWindowsUpdateActiveHours);
    private void MaintenanceScripts_Click(object sender, RoutedEventArgs e) => ShowOutput("Create maintenance scripts", _serverSetupService.CreateMaintenanceScripts);
    private void MaintenanceTasks_Click(object sender, RoutedEventArgs e) => ShowOutput("Register maintenance tasks", _serverSetupService.RegisterMaintenanceTasks);
    private void CreateDashboard_Click(object sender, RoutedEventArgs e) => ShowOutput("Create dashboard files", _serverSetupService.CreateDashboardFiles);
    private void DockerTemplates_Click(object sender, RoutedEventArgs e) => ShowOutput("Create Docker templates", _serverSetupService.CreateDockerTemplates);
    private void DockerAutostart_Click(object sender, RoutedEventArgs e) => ShowOutput("Start Docker apps after login", _serverSetupService.RegisterDockerAutostartTask);
    private void StartDockerApps_Click(object sender, RoutedEventArgs e) => ShowOutput("Start Docker apps now", _serverSetupService.StartAllDockerAppsNow);
    private void DeployUptimeKuma_Click(object sender, RoutedEventArgs e) => ShowOutput("Deploy Uptime Kuma", _serverSetupService.DeployUptimeKuma);
    private void DesktopDropZone_Click(object sender, RoutedEventArgs e) => ShowOutput("Create hosted apps folder", _serverSetupService.CreateDesktopAppsDropZone);
    private void RouterChecklist_Click(object sender, RoutedEventArgs e) => ShowOutput("Create router/BIOS checklist", _serverSetupService.CreateRouterBiosChecklist);
    private void HardenSecrets_Click(object sender, RoutedEventArgs e) => ShowOutput("Harden secrets folders", _serverSetupService.HardenSecretsFolders);
    private void InstallCommonTools_Click(object sender, RoutedEventArgs e) => ShowOutput("Install common tools", _serverSetupService.InstallCommonTools);
    private void InstallTailscale_Click(object sender, RoutedEventArgs e) => ShowOutput("Install Tailscale", _serverSetupService.InstallTailscale);
    private void InstallDocker_Click(object sender, RoutedEventArgs e) => ShowOutput("Install Docker Desktop", _serverSetupService.InstallDockerDesktop);
    private void OpenAdminShell_Click(object sender, RoutedEventArgs e) => ShowOutput("Open Administrator PowerShell", _serverSetupService.OpenAdminPowerShell);
    private void OpenLegacyWizard_Click(object sender, RoutedEventArgs e) => ShowOutput("Open advanced script tools", _serverSetupService.OpenLegacyPowerShellWizard);

    private void OpenRoot_Click(object sender, RoutedEventArgs e)
    {
        ShowOutput("Open C:\\HomeServer", () => _serverSetupService.OpenFolder(HomeForgePaths.RootPath));
    }

    private void OpenPort_Click(object sender, RoutedEventArgs e)
    {
        if (!int.TryParse(PortBox.Text, out var port))
        {
            OutputBox.Text = "Enter a valid TCP port number first.";
            return;
        }

        ShowOutput($"Open private firewall port {port}", () => _serverSetupService.OpenTcpPort(port));
    }
}
