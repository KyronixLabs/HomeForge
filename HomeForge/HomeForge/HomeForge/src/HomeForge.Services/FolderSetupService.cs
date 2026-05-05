using System.IO;
using HomeForge.Core;

namespace HomeForge.Services;

public sealed class FolderSetupService
{
    public void CreateFolderLayout()
    {
        foreach (var folder in new[]
        {
            HomeForgePaths.RootPath,
            HomeForgePaths.Apps,
            HomeForgePaths.AppConnections,
            HomeForgePaths.Backups,
            HomeForgePaths.Config,
            HomeForgePaths.Dashboard,
            HomeForgePaths.Data,
            HomeForgePaths.Logs,
            HomeForgePaths.Reports,
            HomeForgePaths.Restore,
            HomeForgePaths.Scripts,
            HomeForgePaths.Secrets,
            HomeForgePaths.Templates,
            Path.Combine(HomeForgePaths.Config, "desktop-apps"),
            Path.Combine(HomeForgePaths.Data, "desktop-apps"),
            Path.Combine(HomeForgePaths.Logs, "desktop-apps"),
            Path.Combine(HomeForgePaths.Secrets, "desktop-apps"),
            HomeForgePaths.DesktopAppsFolder
        })
        {
            Directory.CreateDirectory(folder);
        }

        var readme = Path.Combine(HomeForgePaths.RootPath, "README-HOMEFORGE.txt");
        if (!File.Exists(readme))
        {
            File.WriteAllText(readme, "HomeForge server folders created. Keep apps, data, scripts, logs and connection packs organised here.\r\n");
        }

        var desktopReadme = Path.Combine(HomeForgePaths.DesktopAppsFolder, "README-FIRST.txt");
        if (!File.Exists(desktopReadme))
        {
            File.WriteAllText(desktopReadme, "Place each server app in its own subfolder, then use HomeForge to scan and approve the launcher.\r\n");
        }
    }
}
