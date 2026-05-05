using System.IO;
using System.Text;
using System.Text.Json;
using HomeForge.Core;
using HomeForge.Models;

namespace HomeForge.Services;

public sealed class AppConnectionService
{
    private readonly NetworkService _networkService;

    public AppConnectionService(NetworkService networkService)
    {
        _networkService = networkService;
    }

    public AppConnectionProfile Generate(
        string appName,
        int localPort,
        PublicAccessMethod method,
        string publicHostOrUrl,
        string endpointsText)
    {
        Directory.CreateDirectory(HomeForgePaths.AppConnections);

        var safeName = SafeName.Make(appName, "App");
        var timestamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
        var folder = Path.Combine(HomeForgePaths.AppConnections, $"{safeName}-{timestamp}");
        Directory.CreateDirectory(folder);

        var localIp = _networkService.GetBestLocalIPv4();
        var endpoints = ParseEndpoints(endpointsText).ToArray();
        if (endpoints.Length == 0)
        {
            endpoints = new[] { "/api/health", "/api/auth/login", "/api/version" };
        }

        var healthEndpoint = endpoints.FirstOrDefault(e => e.Contains("health", StringComparison.OrdinalIgnoreCase)) ?? "/api/health";
        var localUrl = $"http://{localIp}:{localPort}";
        var serverUrl = BuildServerUrl(method, publicHostOrUrl, localUrl);

        var profile = new AppConnectionProfile
        {
            AppName = appName,
            SafeAppName = safeName,
            FolderPath = folder,
            LocalIpAddress = localIp,
            LocalPort = localPort,
            PublicPort = method == PublicAccessMethod.LocalOnly ? localPort : 443,
            AccessMethod = method,
            PublicHostOrUrl = publicHostOrUrl.Trim(),
            LocalTestingUrl = localUrl,
            ServerUrl = serverUrl,
            HealthEndpoint = healthEndpoint,
            HealthUrl = CombineUrl(serverUrl, healthEndpoint),
            Endpoints = endpoints,
            HttpsExpected = method != PublicAccessMethod.LocalOnly,
            GeneratedAt = DateTime.Now
        };

        WriteConnectionFiles(profile);
        return profile;
    }

    private static string BuildServerUrl(PublicAccessMethod method, string publicHostOrUrl, string localUrl)
    {
        var value = publicHostOrUrl.Trim();
        return method switch
        {
            PublicAccessMethod.LocalOnly => localUrl,
            PublicAccessMethod.TailscaleFunnel => string.IsNullOrWhiteSpace(value)
                ? "https://YOUR-DEVICE.YOUR-TAILNET.ts.net"
                : NormalizeHttps(value),
            PublicAccessMethod.ExistingDomainOrDdns => NormalizeHttps(value),
            PublicAccessMethod.DuckDnsPack => NormalizeHttps(value.EndsWith(".duckdns.org", StringComparison.OrdinalIgnoreCase)
                ? value
                : value + ".duckdns.org"),
            _ => localUrl
        };
    }

    private static string NormalizeHttps(string hostOrUrl)
    {
        if (string.IsNullOrWhiteSpace(hostOrUrl))
        {
            return "https://your-public-url.example";
        }

        if (hostOrUrl.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
            hostOrUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            return hostOrUrl.TrimEnd('/');
        }

        return "https://" + hostOrUrl.Trim('/');
    }

    private static string CombineUrl(string baseUrl, string endpoint)
    {
        if (string.IsNullOrWhiteSpace(endpoint))
        {
            return baseUrl.TrimEnd('/');
        }

        var cleanEndpoint = endpoint.StartsWith('/') ? endpoint : "/" + endpoint;
        return baseUrl.TrimEnd('/') + cleanEndpoint;
    }

    private static IEnumerable<string> ParseEndpoints(string endpointsText)
    {
        return (endpointsText ?? string.Empty)
            .Split(new[] { '\r', '\n', ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(e => e.StartsWith('/') ? e : "/" + e)
            .Distinct(StringComparer.OrdinalIgnoreCase);
    }

    private static void WriteConnectionFiles(AppConnectionProfile profile)
    {
        WriteCopyFile(profile);
        WriteJsonFile(profile);
        WriteEndpointFiles(profile);
        WriteTestScript(profile);
        WriteChecklist(profile);
        WriteCaddySnippet(profile);
        WriteFirewallScript(profile);
        WriteOptionalPublicAccessFiles(profile);
        WriteReadme(profile);
    }

    private static void WriteCopyFile(AppConnectionProfile p)
    {
        var copy = string.Join(Environment.NewLine, new[]
        {
            "COPY THIS INTO YOUR APP",
            "=======================",
            string.Empty,
            "App name:",
            p.AppName,
            string.Empty,
            "Server URL:",
            p.ServerUrl,
            string.Empty,
            "Health Check URL:",
            p.HealthUrl,
            string.Empty,
            "Local Testing URL:",
            p.LocalTestingUrl,
            string.Empty,
            "Port:",
            p.PublicPort.ToString(),
            string.Empty,
            "HTTPS expected:",
            p.HttpsExpected.ToString(),
            string.Empty,
            "Generated:",
            p.GeneratedAt.ToString("yyyy-MM-dd HH:mm:ss")
        });

        File.WriteAllText(Path.Combine(p.FolderPath, "COPY-THIS-INTO-YOUR-APP.txt"), copy, Encoding.UTF8);
        File.WriteAllText(Path.Combine(p.FolderPath, "server-url.txt"), p.ServerUrl, Encoding.UTF8);
        File.WriteAllText(Path.Combine(p.FolderPath, "health-check-url.txt"), p.HealthUrl, Encoding.UTF8);
    }

    private static void WriteJsonFile(AppConnectionProfile p)
    {
        var json = JsonSerializer.Serialize(p, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(Path.Combine(p.FolderPath, "app-connection-info.json"), json, Encoding.UTF8);
    }

    private static void WriteEndpointFiles(AppConnectionProfile p)
    {
        var endpoints = string.Join(Environment.NewLine, p.Endpoints.Select(e => CombineUrl(p.ServerUrl, e)));
        File.WriteAllText(Path.Combine(p.FolderPath, "endpoint-urls.txt"), endpoints, Encoding.UTF8);
    }

    private static void WriteTestScript(AppConnectionProfile p)
    {
        var script = new StringBuilder();
        script.AppendLine("$ErrorActionPreference = \"Continue\"");
        script.AppendLine("$urls = @(");

        foreach (var endpoint in p.Endpoints)
        {
            script.Append("    \"");
            script.Append(CombineUrl(p.ServerUrl, endpoint).Replace("\"", "`\""));
            script.AppendLine("\",");
        }

        script.AppendLine(")");
        script.AppendLine();
        script.AppendLine("foreach ($url in $urls) {");
        script.AppendLine("    if ([string]::IsNullOrWhiteSpace($url)) { continue }");
        script.AppendLine("    Write-Host \"Testing $url\"");
        script.AppendLine("    try {");
        script.AppendLine("        $response = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing -TimeoutSec 15");
        script.AppendLine("        Write-Host \"OK $($response.StatusCode) $url\" -ForegroundColor Green");
        script.AppendLine("    } catch {");
        script.AppendLine("        Write-Host \"FAILED $url\" -ForegroundColor Red");
        script.AppendLine("        Write-Host $_.Exception.Message -ForegroundColor Red");
        script.AppendLine("    }");
        script.AppendLine("    Write-Host \"\"");
        script.AppendLine("}");

        File.WriteAllText(Path.Combine(p.FolderPath, "Test-App-Connection.ps1"), script.ToString(), Encoding.UTF8);
    }

    private static void WriteChecklist(AppConnectionProfile p)
    {
        var checklist = string.Join(Environment.NewLine, new[]
        {
            "APP CONNECTION SETUP CHECKLIST",
            "==============================",
            string.Empty,
            $"1. Your app backend is running locally on port {p.LocalPort}.",
            $"2. Local test URL works: {p.LocalTestingUrl}",
            $"3. Health check works: {CombineUrl(p.LocalTestingUrl, p.HealthEndpoint)}",
            $"4. Public server URL is: {p.ServerUrl}",
            "5. Your desktop/mobile/client app should use only the Server URL above.",
            "6. Do not expose databases, logs, backups, workers, admin panels or secrets publicly.",
            "7. Keep only the API/reverse proxy public.",
            string.Empty,
            "Access method selected:",
            p.AccessMethod.ToString()
        });

        File.WriteAllText(Path.Combine(p.FolderPath, "Setup-Checklist.txt"), checklist, Encoding.UTF8);
    }

    private static void WriteCaddySnippet(AppConnectionProfile p)
    {
        var caddy = string.Join(Environment.NewLine, new[]
        {
            $"# Caddy reverse proxy snippet for {p.AppName}",
            "# Use this only if you are using your own domain/DDNS and port forwarding.",
            string.Empty,
            "your-domain.example {",
            $"    reverse_proxy localhost:{p.LocalPort}",
            "}"
        });

        File.WriteAllText(Path.Combine(p.FolderPath, "Caddyfile-snippet.txt"), caddy, Encoding.UTF8);
    }

    private static void WriteFirewallScript(AppConnectionProfile p)
    {
        var ruleName = $"HomeForge - {p.AppName} local port {p.LocalPort}".Replace("\"", "'");
        var firewall = $"New-NetFirewallRule -DisplayName \"{ruleName}\" -Direction Inbound -Action Allow -Protocol TCP -LocalPort {p.LocalPort} -Profile Private" + Environment.NewLine;
        File.WriteAllText(Path.Combine(p.FolderPath, "Open-Firewall-For-This-App.ps1"), firewall, Encoding.UTF8);
    }

    private static void WriteOptionalPublicAccessFiles(AppConnectionProfile p)
    {
        if (p.AccessMethod == PublicAccessMethod.TailscaleFunnel)
        {
            var funnel = string.Join(Environment.NewLine, new[]
            {
                "# Run this on the home server after Tailscale is installed and signed in.",
                $"# It exposes localhost:{p.LocalPort} through your Tailscale ts.net HTTPS address.",
                string.Empty,
                $"tailscale funnel --https=443 localhost:{p.LocalPort}"
            });

            File.WriteAllText(Path.Combine(p.FolderPath, "Start-Tailscale-Funnel.ps1"), funnel, Encoding.UTF8);
            File.WriteAllText(
                Path.Combine(p.FolderPath, "Start-Tailscale-Funnel.bat"),
                "@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%~dp0Start-Tailscale-Funnel.ps1\"\r\npause\r\n",
                Encoding.UTF8);
        }

        if (p.AccessMethod == PublicAccessMethod.DuckDnsPack)
        {
            var duck = string.Join(Environment.NewLine, new[]
            {
                "# DuckDNS update template.",
                "# Replace YOUR_DUCKDNS_TOKEN and your-subdomain.",
                string.Empty,
                "$domain = \"your-subdomain\"",
                "$token = \"YOUR_DUCKDNS_TOKEN\"",
                "Invoke-WebRequest -UseBasicParsing -Uri \"https://www.duckdns.org/update?domains=$domain&token=$token&ip=\""
            });

            File.WriteAllText(Path.Combine(p.FolderPath, "DuckDNS-Update-Template.ps1"), duck, Encoding.UTF8);
        }
    }

    private static void WriteReadme(AppConnectionProfile p)
    {
        var readme = string.Join(Environment.NewLine, new[]
        {
            "README",
            "======",
            string.Empty,
            $"This folder was created by HomeForge for: {p.AppName}",
            string.Empty,
            "The most important file is:",
            "COPY-THIS-INTO-YOUR-APP.txt",
            string.Empty,
            "Use Test-App-Connection.ps1 to test the generated endpoints."
        });

        File.WriteAllText(Path.Combine(p.FolderPath, "README.txt"), readme, Encoding.UTF8);
    }
}
