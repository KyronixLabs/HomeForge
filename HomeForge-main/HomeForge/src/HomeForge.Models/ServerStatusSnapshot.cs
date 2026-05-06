namespace HomeForge.Models;

public sealed class ServerStatusSnapshot
{
    public bool IsAdministrator { get; set; }
    public string ComputerName { get; set; } = Environment.MachineName;
    public string UserName { get; set; } = Environment.UserName;
    public string LocalIpAddress { get; set; } = "Unavailable";
    public string RootPath { get; set; } = @"C:\HomeServer";
    public bool RootExists { get; set; }
    public bool DockerDetected { get; set; }
    public bool TailscaleDetected { get; set; }
    public int DesktopAppFolderCount { get; set; }
    public int ApprovedDesktopAppCount { get; set; }
    public DateTime CapturedAt { get; set; } = DateTime.Now;
}
