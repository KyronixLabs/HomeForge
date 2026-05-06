using System.Windows;
using System.Windows.Controls;
using HomeForge.Core;
using HomeForge.Services;
using HomeForge.App;

namespace HomeForge.App.Views;

public partial class ToolsView : UserControl
{
    private readonly ServerSetupService _serverSetupService;
    private bool _isActionRunning;

    public ToolsView(FolderSetupService folderSetupService, CommandService commandService, ServerSetupService serverSetupService)
    {
        InitializeComponent();
        _serverSetupService = serverSetupService;

        if (!SessionActionLog.HasEntries)
        {
            SessionActionLog.Append("Select an action. System-level changes require administrator access.");
        }

        RefreshOutput(scrollToEnd: false);
        RefreshProgress();
    }

    private void WriteOutput(string text)
    {
        SessionActionLog.Append(text);
        RefreshOutput(scrollToEnd: true);
    }

    private void RefreshOutput(bool scrollToEnd)
    {
        OutputBox.Text = SessionActionLog.Text;

        if (scrollToEnd)
        {
            OutputBox.CaretIndex = OutputBox.Text.Length;
            OutputBox.ScrollToEnd();
        }
        else
        {
            OutputBox.CaretIndex = 0;
            OutputBox.ScrollToHome();
        }
    }

    private void RefreshProgress()
    {
        ProgressPanel.Visibility = SessionActionLog.IsProgressVisible ? Visibility.Visible : Visibility.Collapsed;
        ActionProgressBar.IsIndeterminate = SessionActionLog.IsProgressIndeterminate;
        ActionProgressBar.Value = SessionActionLog.ProgressValue;
        ProgressText.Text = SessionActionLog.ProgressText;
        ProgressPercentText.Text = SessionActionLog.IsProgressIndeterminate ? "Working" : $"{SessionActionLog.ProgressValue:0}%";
    }

    private void SetProgress(double value, string text)
    {
        SessionActionLog.UpdateProgress(value, text);
        RefreshProgress();
    }

    private void SetWorkingProgress(string title)
    {
        SessionActionLog.StartProgress($"{title} is running...", indeterminate: true);
        RefreshProgress();
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

    private async Task ShowOutputAsync(string title, Func<string> action)
    {
        if (_isActionRunning)
        {
            WriteOutput("Another action is already running. Wait for it to finish before starting a new one.");
            return;
        }

        try
        {
            _isActionRunning = true;
            SetWorkingProgress(title);
            WriteOutput($"> {title}\r\n\r\nWorking...\r\n\r\nThis is running in the background. HomeForge will stay responsive while the action completes. Installer and download actions may stay in working mode until Windows reports that the process has finished.");

            var result = await Task.Run(action);

            SessionActionLog.CompleteProgress($"{title} complete.");
            RefreshProgress();
            WriteOutput($"> {title}\r\n\r\n{result}");
        }
        catch (Exception ex)
        {
            SessionActionLog.CompleteProgress($"{title} failed.");
            RefreshProgress();
            WriteOutput($"> {title}\r\n\r\nFAILED\r\n{ex.Message}");
        }
        finally
        {
            _isActionRunning = false;
        }
    }

    private async void CreateFolders_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Create folder layout", _serverSetupService.CreateFolderLayout);
    private async void RecommendedSetup_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Run recommended server setup", _serverSetupService.RunRecommendedSetup);
    private async void PowerSettings_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Configure 24/7 power settings", _serverSetupService.ConfigureAlwaysOnPower);
    private async void DeepPower_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Improve power reliability", _serverSetupService.ConfigureDeepPowerOptimization);
    private async void FirewallBaseline_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Enable Windows Firewall baseline", _serverSetupService.ConfigureFirewallBaseline);
    private async void NetworkPrivate_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Set network profile to Private", _serverSetupService.ConfigureNetworkPrivate);
    private async void UpdateHours_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Set Windows Update active hours", _serverSetupService.ConfigureWindowsUpdateActiveHours);
    private async void MaintenanceScripts_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Create maintenance scripts", _serverSetupService.CreateMaintenanceScripts);
    private async void MaintenanceTasks_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Register maintenance tasks", _serverSetupService.RegisterMaintenanceTasks);
    private async void CreateDashboard_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Create dashboard files", _serverSetupService.CreateDashboardFiles);
    private async void DockerTemplates_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Create Docker templates", _serverSetupService.CreateDockerTemplates);
    private async void DockerAutostart_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Start Docker apps after login", _serverSetupService.RegisterDockerAutostartTask);
    private async void StartDockerApps_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Start Docker apps now", _serverSetupService.StartAllDockerAppsNow);
    private async void DeployUptimeKuma_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Deploy Uptime Kuma", _serverSetupService.DeployUptimeKuma);
    private async void DesktopDropZone_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Create hosted apps folder", _serverSetupService.CreateDesktopAppsDropZone);
    private async void RouterChecklist_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Create router/BIOS checklist", _serverSetupService.CreateRouterBiosChecklist);
    private async void HardenSecrets_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Harden secrets folders", _serverSetupService.HardenSecretsFolders);
    private async void InstallCommonTools_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Install common tools", _serverSetupService.InstallCommonTools);
    private async void InstallTailscale_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Install Tailscale", _serverSetupService.InstallTailscale);
    private async void InstallDocker_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Install Docker Desktop", _serverSetupService.InstallDockerDesktop);
    private async void OpenAdminShell_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Open Administrator PowerShell", _serverSetupService.OpenAdminPowerShell);
    private async void OpenLegacyWizard_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Open advanced script tools", _serverSetupService.OpenLegacyPowerShellWizard);
    private async void OpenRoot_Click(object sender, RoutedEventArgs e) => await ShowOutputAsync("Open C:\\HomeServer", () => _serverSetupService.OpenFolder(HomeForgePaths.RootPath));

    private async void OpenPort_Click(object sender, RoutedEventArgs e)
    {
        if (!int.TryParse(PortBox.Text, out var port))
        {
            WriteOutput("Enter a valid TCP port number first.");
            return;
        }

        await ShowOutputAsync($"Open private firewall port {port}", () => _serverSetupService.OpenTcpPort(port));
    }
}
