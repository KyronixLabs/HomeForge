namespace HomeForge.Models;

public enum PublicAccessMethod
{
    LocalOnly,
    TailscaleFunnel,
    ExistingDomainOrDdns,
    DuckDnsPack
}

public sealed class AppConnectionProfile
{
    public string AppName { get; set; } = "My App";
    public string SafeAppName { get; set; } = "My-App";
    public string FolderPath { get; set; } = string.Empty;
    public string LocalIpAddress { get; set; } = "127.0.0.1";
    public int LocalPort { get; set; } = 5088;
    public int PublicPort { get; set; } = 443;
    public PublicAccessMethod AccessMethod { get; set; } = PublicAccessMethod.TailscaleFunnel;
    public string PublicHostOrUrl { get; set; } = string.Empty;
    public string LocalTestingUrl { get; set; } = string.Empty;
    public string ServerUrl { get; set; } = string.Empty;
    public string HealthEndpoint { get; set; } = "/api/health";
    public string HealthUrl { get; set; } = string.Empty;
    public string[] Endpoints { get; set; } = Array.Empty<string>();
    public bool HttpsExpected { get; set; }
    public DateTime GeneratedAt { get; set; } = DateTime.Now;
}
