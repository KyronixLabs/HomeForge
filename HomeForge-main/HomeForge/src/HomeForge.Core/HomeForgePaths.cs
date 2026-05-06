using System.IO;

namespace HomeForge.Core;

public static class HomeForgePaths
{
    public static string RootPath { get; set; } = @"C:\HomeServer";

    public static string Apps => Path.Combine(RootPath, "apps");
    public static string AppConnections => Path.Combine(RootPath, "app-connections");
    public static string Backups => Path.Combine(RootPath, "backups");
    public static string Config => Path.Combine(RootPath, "config");
    public static string Dashboard => Path.Combine(RootPath, "dashboard");
    public static string Data => Path.Combine(RootPath, "data");
    public static string Logs => Path.Combine(RootPath, "logs");
    public static string Reports => Path.Combine(RootPath, "reports");
    public static string Restore => Path.Combine(RootPath, "restore");
    public static string Scripts => Path.Combine(RootPath, "scripts");
    public static string Secrets => Path.Combine(RootPath, "secrets");
    public static string Templates => Path.Combine(RootPath, "templates");

    public static string DesktopAppsFolder => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
        "Home Server Apps");
}
