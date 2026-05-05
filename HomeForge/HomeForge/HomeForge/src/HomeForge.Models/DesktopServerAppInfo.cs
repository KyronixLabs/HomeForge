namespace HomeForge.Models;

public sealed class DesktopServerAppInfo
{
    public string Name { get; set; } = string.Empty;
    public string FolderPath { get; set; } = string.Empty;
    public string LauncherHint { get; set; } = string.Empty;
    public bool Approved { get; set; }
}
