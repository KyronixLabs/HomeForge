using System.IO;
using HomeForge.Core;
using HomeForge.Models;

namespace HomeForge.Services;

public sealed class DesktopAppService
{
    public string EnsureDropZone()
    {
        Directory.CreateDirectory(HomeForgePaths.DesktopAppsFolder);
        var readme = Path.Combine(HomeForgePaths.DesktopAppsFolder, "README-FIRST.txt");
        if (!File.Exists(readme))
        {
            File.WriteAllText(readme,
                "Put each portable server app in its own folder here. HomeForge will ask you which launcher to approve.\r\n\r\n" +
                "Recommended launchers: start.bat, run.bat, launch.bat, server.bat, start.ps1.\r\n");
        }
        return HomeForgePaths.DesktopAppsFolder;
    }

    public IReadOnlyList<DesktopServerAppInfo> ScanDropZone()
    {
        EnsureDropZone();
        Directory.CreateDirectory(Path.Combine(HomeForgePaths.Config, "desktop-apps"));

        var results = new List<DesktopServerAppInfo>();
        foreach (var folder in Directory.GetDirectories(HomeForgePaths.DesktopAppsFolder))
        {
            var name = Path.GetFileName(folder);
            if (name.StartsWith("_")) continue;
            var safe = SafeName.Make(name);
            var manifest = Path.Combine(HomeForgePaths.Config, "desktop-apps", safe + ".json");
            var launcher = FindLauncher(folder);
            results.Add(new DesktopServerAppInfo
            {
                Name = name,
                FolderPath = folder,
                LauncherHint = launcher ?? "No obvious launcher found",
                Approved = File.Exists(manifest)
            });
        }
        return results;
    }

    private static string? FindLauncher(string folder)
    {
        foreach (var name in new[] { "start.bat", "run.bat", "launch.bat", "server.bat", "start.cmd", "run.cmd", "start.ps1", "run.ps1" })
        {
            var path = Path.Combine(folder, name);
            if (File.Exists(path)) return path;
        }

        return Directory.GetFiles(folder, "*.exe", SearchOption.AllDirectories)
            .FirstOrDefault(path => !Path.GetFileName(path).Contains("uninstall", StringComparison.OrdinalIgnoreCase) &&
                                    !Path.GetFileName(path).Contains("setup", StringComparison.OrdinalIgnoreCase));
    }
}
