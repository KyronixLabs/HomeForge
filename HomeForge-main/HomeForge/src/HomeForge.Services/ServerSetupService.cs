using System.Diagnostics;
using System.IO;
using System.Net.NetworkInformation;
using System.Text;
using HomeForge.Core;

namespace HomeForge.Services;

public sealed class ServerSetupService
{
    private readonly FolderSetupService _folderSetupService;
    private readonly NetworkService _networkService;
    private readonly CommandService _commandService;

    public ServerSetupService(FolderSetupService folderSetupService, NetworkService networkService, CommandService commandService)
    {
        _folderSetupService = folderSetupService;
        _networkService = networkService;
        _commandService = commandService;
    }

    public string RunRecommendedSetup()
    {
        var log = new StringBuilder();
        Append(log, "Running recommended HomeForge server setup...");
        _folderSetupService.CreateFolderLayout();
        Append(log, "Created or repaired folder layout.");
        Append(log, ConfigureAlwaysOnPower());
        Append(log, ConfigureDeepPowerOptimization());
        Append(log, ConfigureFirewallBaseline());
        Append(log, ConfigureWindowsUpdateActiveHours());
        Append(log, CreateMaintenanceScripts());
        Append(log, RegisterMaintenanceTasks());
        Append(log, CreateDockerTemplates());
        Append(log, RegisterDockerAutostartTask());
        Append(log, CreateRouterBiosChecklist());
        Append(log, CreateDashboardFiles());
        Append(log, CreateDesktopAppsDropZone());
        Append(log, "Recommended setup complete. Reboot if Windows asks, then add your apps.");
        return log.ToString();
    }

    public string CreateFolderLayout()
    {
        _folderSetupService.CreateFolderLayout();
        return "Folder layout created or repaired.";
    }

    public string ConfigureAlwaysOnPower()
    {
        var output = new StringBuilder();
        Append(output, RunCapture("powercfg.exe", "/change monitor-timeout-ac 10"));
        Append(output, RunCapture("powercfg.exe", "/change standby-timeout-ac 0"));
        Append(output, RunCapture("powercfg.exe", "/change hibernate-timeout-ac 0"));
        Append(output, RunCapture("powercfg.exe", "/hibernate off"));
        Append(output, "Always-on power settings applied. Some options require Administrator mode.");
        return output.ToString();
    }

    public string ConfigureDeepPowerOptimization()
    {
        var script = @"
$ErrorActionPreference = 'Continue'
powercfg /change monitor-timeout-ac 10
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /hibernate off
$settings = @(
    @{ Sub='0012ee47-9041-4b5d-9b77-535fba8b1442'; Set='6738e2c4-e8a5-4a42-b16a-e040e769756e'; Value=0; Name='Disk sleep: never' },
    @{ Sub='2a737441-1930-4402-8d77-b2bebba308a3'; Set='48e6b7a6-50f5-4782-a5d4-53bb8f07e226'; Value=0; Name='USB selective suspend: disabled' },
    @{ Sub='501a4d13-42af-4429-9fd1-a8218c268e20'; Set='ee12f906-d277-404b-b6da-e5fa1a576df5'; Value=0; Name='PCIe link-state power management: off' }
)
foreach ($item in $settings) {
    powercfg /setacvalueindex SCHEME_CURRENT $item.Sub $item.Set $item.Value | Out-Null
    Write-Host $item.Name
}
powercfg /setactive SCHEME_CURRENT
";
        var result = RunPowerShellInline(script, 60);
        return "Power reliability settings applied.\r\n" + result;
    }

    public string ConfigureFirewallBaseline()
    {
        var script = "Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True; Write-Host 'Windows Firewall enabled for all profiles.'";
        return RunPowerShellInline(script, 60);
    }

    public string ConfigureNetworkPrivate()
    {
        var script = @"
$profiles = Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne 'DomainAuthenticated' }
foreach ($profile in $profiles) {
    Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private
    Write-Host ('Set network profile to Private: ' + $profile.Name)
}
";
        return RunPowerShellInline(script, 60);
    }

    public string ConfigureWindowsUpdateActiveHours()
    {
        var script = @"
$wuPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
New-Item -Path $wuPath -Force | Out-Null
New-ItemProperty -Path $wuPath -Name ActiveHoursStart -Value 6 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $wuPath -Name ActiveHoursEnd -Value 2 -PropertyType DWord -Force | Out-Null
Write-Host 'Windows Update active hours set to 06:00-02:00.'
";
        return RunPowerShellInline(script, 60);
    }

    public string CreateMaintenanceScripts()
    {
        Directory.CreateDirectory(HomeForgePaths.Scripts);
        Directory.CreateDirectory(HomeForgePaths.Logs);
        Directory.CreateDirectory(HomeForgePaths.Backups);
        Directory.CreateDirectory(HomeForgePaths.Dashboard);

        File.WriteAllText(Path.Combine(HomeForgePaths.Scripts, "Backup-HomeForge.ps1"), BackupScript(), Encoding.UTF8);
        File.WriteAllText(Path.Combine(HomeForgePaths.Scripts, "Restore-HomeForge.ps1"), RestoreScript(), Encoding.UTF8);
        File.WriteAllText(Path.Combine(HomeForgePaths.Scripts, "Health-Check.ps1"), HealthCheckScript(), Encoding.UTF8);
        File.WriteAllText(Path.Combine(HomeForgePaths.Scripts, "Start-All-Docker-Apps.ps1"), DockerAutostartScript(), Encoding.UTF8);
        CreateDashboardFiles();
        return "Created backup, restore, health-check, dashboard and Docker startup scripts.";
    }

    public string RegisterMaintenanceTasks()
    {
        CreateMaintenanceScripts();
        var backup = Path.Combine(HomeForgePaths.Scripts, "Backup-HomeForge.ps1");
        var health = Path.Combine(HomeForgePaths.Scripts, "Health-Check.ps1");
        var output = new StringBuilder();
        Append(output, RunCapture("schtasks.exe", $"/Create /TN \"\\HomeForge\\Daily Backup\" /SC DAILY /ST 03:00 /TR \"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \\\"{backup}\\\"\" /RU SYSTEM /RL HIGHEST /F"));
        Append(output, RunCapture("schtasks.exe", $"/Create /TN \"\\HomeForge\\Health Check\" /SC MINUTE /MO 15 /TR \"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \\\"{health}\\\"\" /RU SYSTEM /RL HIGHEST /F"));
        Append(output, "Registered backup and health-check scheduled tasks.");
        return output.ToString();
    }

    public string RegisterDockerAutostartTask()
    {
        CreateMaintenanceScripts();
        var dockerScript = Path.Combine(HomeForgePaths.Scripts, "Start-All-Docker-Apps.ps1");
        var args = $"/Create /TN \"\\HomeForge\\Start Docker Apps\" /SC ONLOGON /TR \"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \\\"{dockerScript}\\\"\" /F";
        return RunCapture("schtasks.exe", args) + "\r\nRegistered Docker Compose startup task.";
    }

    public string CreateDockerTemplates()
    {
        var dockerDir = Path.Combine(HomeForgePaths.Templates, "docker");
        var uptimeDir = Path.Combine(HomeForgePaths.Apps, "uptime-kuma");
        Directory.CreateDirectory(dockerDir);
        Directory.CreateDirectory(uptimeDir);
        File.WriteAllText(Path.Combine(dockerDir, "docker-compose.example.yml"), @"services:
  myapp:
    image: your/image:latest
    container_name: myapp
    restart: unless-stopped
    ports:
      - ""8080:8080""
    volumes:
      - C:/HomeServer/data/myapp:/data
", Encoding.UTF8);
        File.WriteAllText(Path.Combine(uptimeDir, "docker-compose.yml"), @"services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - ""3001:3001""
    volumes:
      - C:/HomeServer/data/uptime-kuma:/app/data
", Encoding.UTF8);
        return "Docker and Uptime Kuma templates created.";
    }

    public string StartAllDockerAppsNow()
    {
        CreateMaintenanceScripts();
        var script = Path.Combine(HomeForgePaths.Scripts, "Start-All-Docker-Apps.ps1");
        return RunCapture("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -File \"{script}\"", 300);
    }

    public string DeployUptimeKuma()
    {
        CreateDockerTemplates();
        var dir = Path.Combine(HomeForgePaths.Apps, "uptime-kuma");
        return RunCapture("docker.exe", $"compose --project-directory \"{dir}\" up -d", 300);
    }

    public string CreateDesktopAppsDropZone()
    {
        Directory.CreateDirectory(HomeForgePaths.DesktopAppsFolder);
        var readme = Path.Combine(HomeForgePaths.DesktopAppsFolder, "README-FIRST.txt");
        if (!File.Exists(readme))
        {
            File.WriteAllText(readme, "Put each server app in its own folder. Prefer a start.bat, run.bat or launch.bat file. Then approve the app inside HomeForge.\r\n", Encoding.UTF8);
        }
        Directory.CreateDirectory(Path.Combine(HomeForgePaths.Data, "desktop-apps"));
        Directory.CreateDirectory(Path.Combine(HomeForgePaths.Logs, "desktop-apps"));
        Directory.CreateDirectory(Path.Combine(HomeForgePaths.Secrets, "desktop-apps"));
        return "Hosted applications folder created.";
    }

    public string HardenSecretsFolders()
    {
        Directory.CreateDirectory(HomeForgePaths.Secrets);
        var user = Environment.UserDomainName + "\\" + Environment.UserName;
        var output = new StringBuilder();
        Append(output, RunCapture("icacls.exe", $"\"{HomeForgePaths.Secrets}\" /inheritance:r"));
        Append(output, RunCapture("icacls.exe", $"\"{HomeForgePaths.Secrets}\" /grant:r \"{user}:(OI)(CI)F\" \"Administrators:(OI)(CI)F\" \"SYSTEM:(OI)(CI)F\""));
        Append(output, "Secrets folder permission hardening attempted.");
        return output.ToString();
    }

    public string InstallCommonTools()
    {
        var commands = new[]
        {
            "install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity",
            "install --id 7zip.7zip -e --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity",
            "install --id Microsoft.PowerShell -e --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
        };
        return RunWingetCommands(commands, 3600);
    }

    public string InstallDockerDesktop() => RunWingetCommands(new[] { "install --id Docker.DockerDesktop -e --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" }, 3600);
    public string InstallTailscale() => RunWingetCommands(new[] { "install --id Tailscale.Tailscale -e --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" }, 2400);

    public string OpenTcpPort(int port)
    {
        if (port < 1 || port > 65535) return "Invalid port. Use 1-65535.";
        var script = $"New-NetFirewallRule -DisplayName 'HomeForge App Port {port}' -Direction Inbound -Action Allow -Protocol TCP -LocalPort {port} -Profile Private -ErrorAction SilentlyContinue; Write-Host 'Opened private TCP port {port}.'";
        return RunPowerShellInline(script, 60);
    }

    public string CreateRouterBiosChecklist()
    {
        Directory.CreateDirectory(HomeForgePaths.Reports);
        var ip = _networkService.GetBestLocalIPv4();
        var mac = _networkService.GetPrimaryMacAddress();
        var gateway = GetGatewayAddress();
        var suggested = SuggestReservedIp(ip, gateway);
        var file = Path.Combine(HomeForgePaths.Reports, "Router-BIOS-Checklist.txt");
        var content = $@"HomeForge Router / BIOS Checklist
Generated: {DateTime.Now}

PC name: {Environment.MachineName}
User: {Environment.UserName}
Local IP: {ip}
MAC address for router DHCP reservation: {mac}
Gateway/router: {gateway}
Suggested reserved IP: {suggested}

Router tasks:
1. Open your router page, usually http://{gateway}
2. Find DHCP reservation / LAN devices / address reservation.
3. Reserve MAC address {mac} to IP {suggested}.
4. Save changes and restart the server.

BIOS/UEFI tasks:
1. Reboot and enter BIOS/UEFI.
2. Enable: Power On After AC Loss / Restore on AC Power Loss / AC Back Always On.
3. Optional: enable Wake on LAN.

Remote access advice:
- Prefer Tailscale Funnel for no-domain public HTTPS.
- Do not expose Remote Desktop directly to the internet.
";
        File.WriteAllText(file, content, Encoding.UTF8);
        return "Router/BIOS checklist written to: " + file;
    }

    public string CreateDashboardFiles()
    {
        Directory.CreateDirectory(HomeForgePaths.Dashboard);
        var html = @"<!doctype html>
<html><head><meta charset=""utf-8""><title>HomeForge Dashboard</title>
<style>body{font-family:Segoe UI;background:#070A0F;color:#E8EDF4;padding:30px}.card{background:#0E1520;border:1px solid #223044;border-radius:16px;padding:20px;margin:12px 0}h1,h2{color:#D7A84B}code{color:#D7A84B}</style>
</head><body><h1>HomeForge Dashboard</h1><div class=""card""><h2>Server</h2><p>Root: <code>C:\HomeServer</code></p><p>Run Health-Check.ps1 for live reports.</p></div></body></html>";
        File.WriteAllText(Path.Combine(HomeForgePaths.Dashboard, "index.html"), html, Encoding.UTF8);
        return "Local dashboard written to: " + Path.Combine(HomeForgePaths.Dashboard, "index.html");
    }

    public string OpenLegacyPowerShellWizard()
    {
        var scriptPath = FindLegacyScript();
        if (scriptPath is null) return "Advanced script tools are not included in this package.";
        Process.Start(new ProcessStartInfo("powershell.exe")
        {
            UseShellExecute = true,
            Verb = "runas",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\""
        });
        return "Launched advanced script tools as Administrator.";
    }

    public string OpenAdminPowerShell()
    {
        Process.Start(new ProcessStartInfo("powershell.exe") { UseShellExecute = true, Verb = "runas" });
        return "Opened PowerShell as Administrator.";
    }

    public string OpenFolder(string path)
    {
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
        return "Opened: " + path;
    }

    private string RunWingetCommands(IEnumerable<string> commands, int timeoutSeconds)
    {
        var output = new StringBuilder();
        Append(output, "Checking Windows Package Manager...");
        var info = RunCapture("winget.exe", "--info", 30);
        Append(output, info);

        if (info.Contains("The system cannot find", StringComparison.OrdinalIgnoreCase) ||
            info.Contains("not recognized", StringComparison.OrdinalIgnoreCase))
        {
            Append(output, "winget was not found. Install App Installer from Microsoft Store, then run this action again.");
            return output.ToString();
        }

        Append(output, "Updating winget package sources...");
        Append(output, RunCapture("winget.exe", "source update --disable-interactivity", 300));

        foreach (var command in commands)
        {
            Append(output, "> winget " + command);
            Append(output, RunCapture("winget.exe", command, timeoutSeconds));
        }

        Append(output, "Install action finished. Some tools may require a reboot or a sign in step before HomeForge can use them.");
        return output.ToString();
    }

    private string RunCapture(string fileName, string arguments, int timeoutSeconds = 120)
    {
        try
        {
            var result = _commandService.Run(fileName, arguments, timeoutSeconds);
            var text = new StringBuilder();
            if (!string.IsNullOrWhiteSpace(result.StandardOutput)) text.AppendLine(result.StandardOutput.Trim());
            if (!string.IsNullOrWhiteSpace(result.StandardError)) text.AppendLine(result.StandardError.Trim());
            if (!result.Success) text.AppendLine($"Exit code: {result.ExitCode}");
            return text.Length == 0 ? "Done." : text.ToString();
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }

    private string RunPowerShellInline(string script, int timeoutSeconds)
    {
        try
        {
            var temp = Path.Combine(Path.GetTempPath(), "HomeForge-" + Guid.NewGuid().ToString("N") + ".ps1");
            File.WriteAllText(temp, script, Encoding.UTF8);
            return RunCapture("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -File \"{temp}\"", timeoutSeconds);
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }

    private static void Append(StringBuilder builder, string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return;
        builder.AppendLine(text.TrimEnd());
        builder.AppendLine();
    }

    private static string? FindLegacyScript()
    {
        var dir = AppContext.BaseDirectory;
        for (var i = 0; i < 8 && dir is not null; i++)
        {
            var candidate = Path.Combine(dir, "tools", "PowerShellLegacy", "HomeForge.PowerShell.v4.1.ps1");
            if (File.Exists(candidate)) return candidate;
            dir = Directory.GetParent(dir)?.FullName;
        }
        return null;
    }

    private static string GetGatewayAddress()
    {
        try
        {
            foreach (var networkInterface in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (networkInterface.OperationalStatus != OperationalStatus.Up) continue;
                var gateway = networkInterface.GetIPProperties().GatewayAddresses.FirstOrDefault(g => g.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork);
                if (gateway is not null) return gateway.Address.ToString();
            }
        }
        catch { }
        return "192.168.1.1";
    }

    private static string SuggestReservedIp(string ip, string gateway)
    {
        try
        {
            var parts = gateway.Split('.');
            if (parts.Length == 4) return $"{parts[0]}.{parts[1]}.{parts[2]}.50";
        }
        catch { }
        return ip;
    }

    private static string BackupScript() => @"
param([string]$Root='C:\HomeServer')
$ErrorActionPreference='Stop'
$stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$target=Join-Path $Root 'backups'
New-Item -ItemType Directory -Path $target -Force | Out-Null
$sources=@('data','apps','config','scripts','secrets','templates') | ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path $_ }
$out=Join-Path $target ""homeforge-backup-$stamp.zip""
Compress-Archive -Path $sources -DestinationPath $out -Force
Write-Host ""Backup created: $out""
";

    private static string RestoreScript() => @"
param([string]$Root='C:\HomeServer',[string]$BackupZip='')
if([string]::IsNullOrWhiteSpace($BackupZip)){ $BackupZip=Read-Host 'Backup zip path' }
$stage=Join-Path $Root ('restore\stage-' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Expand-Archive -Path $BackupZip -DestinationPath $stage -Force
Write-Host ""Extracted to $stage. Review files before copying into production folders.""
";

    private static string HealthCheckScript() => @"
param([string]$Root='C:\HomeServer')
$log=Join-Path $Root 'logs\health-report.txt'
New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
'HomeForge health report - ' + (Get-Date) | Out-File $log
'Computer: ' + $env:COMPUTERNAME | Out-File $log -Append
'User: ' + $env:USERNAME | Out-File $log -Append
'IP addresses:' | Out-File $log -Append
Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias,IPAddress | Format-Table | Out-String | Out-File $log -Append
'Docker containers:' | Out-File $log -Append
try { docker ps -a | Out-File $log -Append } catch { 'Docker unavailable' | Out-File $log -Append }
Write-Host ""Health report written to $log""
";

    private static string DockerAutostartScript() => @"
param([string]$Root='C:\HomeServer')
$log=Join-Path $Root 'logs\docker-autostart.log'
New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
Get-ChildItem -Path (Join-Path $Root 'apps') -Recurse -Include docker-compose.yml,docker-compose.yaml,compose.yml,compose.yaml -ErrorAction SilentlyContinue | ForEach-Object {
    Push-Location $_.DirectoryName
    docker compose up -d 2>&1 | Out-File $log -Append
    Pop-Location
}
";
}
