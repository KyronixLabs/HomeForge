using System.IO;
using System.Security.Principal;
using HomeForge.Core;
using HomeForge.Models;

namespace HomeForge.Services;

public sealed class SystemStatusService
{
    private readonly NetworkService _networkService;
    private readonly CommandService _commandService;

    public SystemStatusService(NetworkService networkService, CommandService commandService)
    {
        _networkService = networkService;
        _commandService = commandService;
    }

    public ServerStatusSnapshot GetSnapshot()
    {
        var desktopFolder = HomeForgePaths.DesktopAppsFolder;
        var manifestFolder = Path.Combine(HomeForgePaths.Config, "desktop-apps");

        return new ServerStatusSnapshot
        {
            IsAdministrator = IsAdministrator(),
            ComputerName = Environment.MachineName,
            UserName = Environment.UserName,
            LocalIpAddress = _networkService.GetBestLocalIPv4(),
            RootPath = HomeForgePaths.RootPath,
            RootExists = Directory.Exists(HomeForgePaths.RootPath),
            DockerDetected = _commandService.CommandExists("docker.exe"),
            TailscaleDetected = _commandService.CommandExists("tailscale.exe"),
            DesktopAppFolderCount = Directory.Exists(desktopFolder)
                ? Directory.GetDirectories(desktopFolder).Count(d => !Path.GetFileName(d).StartsWith("_"))
                : 0,
            ApprovedDesktopAppCount = Directory.Exists(manifestFolder)
                ? Directory.GetFiles(manifestFolder, "*.json").Length
                : 0,
            CapturedAt = DateTime.Now
        };
    }

    public static bool IsAdministrator()
    {
        using var identity = WindowsIdentity.GetCurrent();
        var principal = new WindowsPrincipal(identity);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }
}
