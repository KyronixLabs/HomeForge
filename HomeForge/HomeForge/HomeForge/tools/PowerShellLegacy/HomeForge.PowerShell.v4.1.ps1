<#
HomeForge.ps1
Version 4.1
A Windows 11 Home Server Setup Tool for turning a mini PC into a safer 24/7 home server.

Run with the included .bat launcher, or from an elevated PowerShell session:
  powershell.exe -ExecutionPolicy Bypass -File .\HomeServerSetupWizard.ps1

This script automates Windows-side setup and generates templates/checklists for things Windows cannot safely control.
Risky or account-specific changes remain behind explicit prompts.
#>

[CmdletBinding()]
param(
    [string]$Root = "C:\HomeServer",
    [switch]$Auto,
    [switch]$SkipToolInstall
)

$ErrorActionPreference = "Stop"
$Script:LogFile = $null
$Script:ConfigPath = $null
$Script:Version = "4.1"
$Script:AppName = "HomeForge"
$Script:LastNotice = "Ready"

function Set-ConsoleTheme {
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::UTF8 } catch {}
    try { $host.UI.RawUI.WindowTitle = "$Script:AppName v$Script:Version" } catch {}
    try { $Host.UI.RawUI.BackgroundColor = "Black"; $Host.UI.RawUI.ForegroundColor = "Gray"; Clear-Host } catch {}
}

function Get-UIWidth {
    try {
        $w = $Host.UI.RawUI.WindowSize.Width
        if ($w -lt 90) { return 90 }
        if ($w -gt 120) { return 120 }
        return $w - 2
    } catch { return 100 }
}

function Write-HFLine([string]$Text = "", [string]$Color = "Gray") {
    Write-Host $Text -ForegroundColor $Color
}

function Write-HFBorder([string]$Position = "mid", [int]$Width = 100, [string]$Color = "DarkYellow") {
    $inner = [Math]::Max(4, $Width - 2)
    switch ($Position) {
        "top" { $line = '┌' + ('─' * $inner) + '┐' }
        "bottom" { $line = '└' + ('─' * $inner) + '┘' }
        default { $line = '├' + ('─' * $inner) + '┤' }
    }
    Write-Host $line -ForegroundColor $Color
}

function Write-HFRow([string]$Text, [int]$Width = 100, [string]$Color = "Gray") {
    $inner = [Math]::Max(4, $Width - 2)
    $trimmed = if ($Text.Length -gt $inner) { $Text.Substring(0, $inner) } else { $Text }
    $pad = ' ' * [Math]::Max(0, $inner - $trimmed.Length)
    Write-Host ('│' + $trimmed + $pad + '│') -ForegroundColor $Color
}

function Get-HomeForgeStatus {
    $cfg = Get-HomeServerConfig
    $rootExists = Test-Path $Root
    $desktopPath = Get-DesktopServerAppsFolder
    $desktopCount = if (Test-Path $desktopPath) { @(Get-ChildItem -Path $desktopPath -Directory -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.StartsWith('_') }).Count } else { 0 }
    $approvedApps = if (Test-Path "$Root\config\desktop-apps") { @(Get-ChildItem "$Root\config\desktop-apps" -Filter '*.json' -ErrorAction SilentlyContinue).Count } else { 0 }
    $dockerOk = Test-DockerAvailable
    $backupTarget = if ($cfg -and $cfg.BackupTarget) { $cfg.BackupTarget } else { "$Root\backups" }
    $lastBackup = Get-ChildItem -Path $backupTarget -Filter 'homeserver-backup-*.*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $lastBackupText = if ($lastBackup) { $lastBackup.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } else { 'None yet' }
    $taskCount = try { @(Get-ScheduledTask -TaskPath '\HomeServer\' -ErrorAction Stop).Count } catch { 0 }
    [ordered]@{
        'Admin Mode' = if (Test-IsAdmin) { 'Yes' } else { 'No' }
        'Server Root' = if ($rootExists) { $Root } else { 'Not created yet' }
        'Docker' = if ($dockerOk) { 'Ready' } else { 'Not detected' }
        'Desktop Apps' = "$approvedApps approved / $desktopCount folders"
        'Scheduled Tasks' = if ($taskCount -gt 0) { "$taskCount configured" } else { 'Not configured' }
        'Last Backup' = $lastBackupText
        'Last Notice' = $Script:LastNotice
    }
}

function Write-Title {
    Set-ConsoleTheme
    Clear-Host
    $width = Get-UIWidth
    Write-HFBorder -Position top -Width $width
    Write-HFRow ("  H O M E F O R G E".PadRight($width - 2)) -Width $width -Color Yellow
    Write-HFRow ("  Always-on Windows home server control panel".PadRight($width - 2)) -Width $width -Color Gray
    Write-HFRow (("  Root: " + $Root).PadRight($width - 2)) -Width $width -Color DarkGray
    Write-HFBorder -Position bottom -Width $width
    Write-Host ""
    Write-Host ("STATUS".PadLeft([Math]::Floor($width/2)+3,' ')) -ForegroundColor Yellow
    Write-HFBorder -Position top -Width $width
    $header = (' {0,-24} {1,-45} {2,-10}' -f 'Parameter','Value','Status')
    Write-HFRow $header -Width $width -Color Gray
    Write-HFBorder -Position mid -Width $width
    $status = Get-HomeForgeStatus
    foreach ($key in $status.Keys) {
        $value = [string]$status[$key]
        $state = if ($value -match 'Not|None|No') { 'CHECK' } elseif ($value -match 'Ready|Yes|configured|approved') { 'OK' } else { 'INFO' }
        $row = (' {0,-24} {1,-45} {2,-10}' -f $key, $value, $state)
        $rowColor = switch ($state) { 'OK' {'Green'} 'CHECK' {'Red'} default {'Gray'} }
        Write-HFRow $row -Width $width -Color $rowColor
    }
    Write-HFBorder -Position bottom -Width $width
    Write-Host ""
}

function Write-Section([string]$Text) {
    Write-Host ""
    Write-Host ("[ " + $Text + " ]") -ForegroundColor Yellow
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-AsAdminIfNeeded {
    if (Test-IsAdmin) { return }
    Write-Host "This setup needs administrator rights. Relaunching as administrator..." -ForegroundColor Yellow
    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`"",
        "-Root", "`"$Root`""
    )
    if ($Auto) { $argList += "-Auto" }
    if ($SkipToolInstall) { $argList += "-SkipToolInstall" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

function Confirm-Choice([string]$Message, [bool]$DefaultYes = $true) {
    if ($Auto) { return $DefaultYes }
    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    while ($true) {
        $answer = Read-Host "$Message $suffix"
        if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultYes }
        switch ($answer.Trim().ToLowerInvariant()) {
            "y" { return $true }
            "yes" { return $true }
            "n" { return $false }
            "no" { return $false }
            default { Write-Host "Please type y or n." -ForegroundColor DarkYellow }
        }
    }
}

function Read-Default([string]$Prompt, [string]$DefaultValue) {
    $answer = Read-Host "$Prompt [$DefaultValue]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultValue }
    return $answer.Trim()
}

function Invoke-Step([string]$Name, [scriptblock]$Action) {
    Write-Host "`n[$Name]" -ForegroundColor Cyan
    try {
        & $Action
        Write-Host "Done: $Name" -ForegroundColor Green
        $Script:LastNotice = "Done: $Name"
        if ($Script:LogFile) { "[$(Get-Date -Format s)] DONE: $Name" | Out-File -FilePath $Script:LogFile -Append -Encoding UTF8 }
    }
    catch {
        Write-Host "Failed: $Name" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        $Script:LastNotice = "Failed: $Name"
        if ($Script:LogFile) {
            "[$(Get-Date -Format s)] FLED: $Name -- $($_.Exception.Message)" | Out-File -FilePath $Script:LogFile -Append -Encoding UTF8
        }
    }
}

function Initialize-Logging {
    New-Item -ItemType Directory -Path "$Root\logs" -Force | Out-Null
    $Script:LogFile = Join-Path $Root ("logs\setup-{0}.log" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"))
    "HomeForge v$Script:Version log started: $(Get-Date)" | Out-File -FilePath $Script:LogFile -Encoding UTF8
    try { Start-Transcript -Path $Script:LogFile -Append | Out-Null } catch {}
}

function Get-DefaultConfig {
    [ordered]@{
        Version = $Script:Version
        Root = $Root
        TimeZone = "Europe/London"
        BackupTarget = "$Root\backups"
        BackupRetention = 14
        LowDiskFreePercent = 15
        LowDiskFreeGB = 10
        AlertProvider = "none"
        DiscordWebhookUrl = ""
        TelegramBotToken = ""
        TelegramChatId = ""
        NtfyTopic = ""
        GotifyUrl = ""
        GotifyToken = ""
        SmtpServer = ""
        SmtpPort = 587
        SmtpUseSsl = $true
        SmtpFrom = ""
        SmtpTo = ""
        LastBackupPath = ""
        DashboardPath = "$Root\dashboard\index.html"
        DesktopAppsFolder = (Join-Path ([Environment]::GetFolderPath("Desktop")) "Home Server Apps")
        DesktopAppRestartDelaySeconds = 10
        DesktopAppAutoStartApprovedOnly = $true
    }
}

function Initialize-Config {
    New-Item -ItemType Directory -Path "$Root\config" -Force | Out-Null
    $Script:ConfigPath = Join-Path $Root "config\homeserver.config.json"
    if (-not (Test-Path $Script:ConfigPath)) {
        Get-DefaultConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $Script:ConfigPath -Encoding UTF8
    }
}

function Get-HomeServerConfig {
    Initialize-Config
    try {
        $cfg = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        $cfg = Get-DefaultConfig | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    }
    $defaults = Get-DefaultConfig
    foreach ($key in $defaults.Keys) {
        if ($cfg.PSObject.Properties.Name -notcontains $key) {
            $cfg | Add-Member -MemberType NoteProperty -Name $key -Value $defaults[$key]
        }
    }
    return $cfg
}

function Save-HomeServerConfig([object]$Config) {
    Initialize-Config
    $Config | ConvertTo-Json -Depth 8 | Out-File -FilePath $Script:ConfigPath -Encoding UTF8
}

function Write-TextFile([string]$Path, [string]$Content) {
    $folder = Split-Path -Path $Path -Parent
    if ($folder) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    $Content | Out-File -FilePath $Path -Encoding UTF8
}

function Create-FolderLayout {
    $folders = @(
        $Root,
        "$Root\apps",
        "$Root\apps\_examples",
        "$Root\app-connections",
        "$Root\config",
        "$Root\dashboard",
        "$Root\data",
        "$Root\backups",
        "$Root\scripts",
        "$Root\logs",
        "$Root\templates",
        "$Root\downloads",
        "$Root\secrets",
        "$Root\restore",
        "$Root\reports"
    )
    foreach ($folder in $folders) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    Initialize-Config
    Create-DesktopServerAppsFolder

    $readme = @"
# HomeServer folder layout

Created by HomeServerSetupWizard.ps1 v$Script:Version.

## Folders

- apps: Docker Compose folders, app launchers, and startup task folders
- config: HomeServer wizard configuration
- dashboard: local status dashboard
- data: persistent application data that should be backed up
- backups: generated backups
- scripts: maintenance, backup, health, restore, and Docker start scripts
- logs: setup logs, health reports, backup logs, and app-start logs
- templates: Docker Compose, reverse proxy, remote access, and service templates
- secrets: local secret notes or .env templates; back this up carefully and do not publish it
- restore: restore staging area
- reports: generated security/network/router reports

## Manual tasks Windows cannot safely finish

1. Router: create a DHCP reservation for this mini PC.
2. BIOS/UEFI: enable "Power on after AC loss" / "Restore AC power loss".
3. Accounts: log in to Tailscale/Cloudflare/other providers where needed.
4. Apps: add your real application config, secrets, and ports.
5. Desktop Server Apps: place portable Windows apps in the Desktop drop-zone, then approve them in HomeForge.

Prefer VPN-style access over direct router port forwards.
"@
    Write-TextFile "$Root\README.md" $readme
}

function Configure-PowerForServer {
    powercfg /change monitor-timeout-ac 10 | Out-Null
    powercfg /change standby-timeout-ac 0 | Out-Null
    powercfg /change hibernate-timeout-ac 0 | Out-Null
    powercfg /hibernate off | Out-Null

    try {
        $adapters = Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            try { Set-NetAdapterPowerManagement -Name $adapter.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop | Out-Null } catch {}
        }
    } catch {}
}

function Configure-DeepPowerOptimization {
    # AC values only; keeps laptop/battery behaviour largely untouched if this is run on a portable machine.
    $activeScheme = (powercfg /getactivescheme) -join " "
    Write-Host $activeScheme

    $settings = @(
        @{ Sub="0012ee47-9041-4b5d-9b77-535fba8b1442"; Set="6738e2c4-e8a5-4a42-b16a-e040e769756e"; Value=0; Name="Turn off hard disk after: Never" },
        @{ Sub="2a737441-1930-4402-8d77-b2bebba308a3"; Set="48e6b7a6-50f5-4782-a5d4-53bb8f07e226"; Value=0; Name="USB selective suspend: Disabled" },
        @{ Sub="501a4d13-42af-4429-9fd1-a8218c268e20"; Set="ee12f906-d277-404b-b6da-e5fa1a576df5"; Value=0; Name="PCIe link-state power management: Off" },
        @{ Sub="238c9fa8-0aad-41ed-83f4-97be242c8f20"; Set="bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d"; Value=0; Name="Wake timers: Disabled" },
        @{ Sub="19cbb8fa-5279-450e-9fac-8a3d5fedd0c1"; Set="12bbebe6-58d6-4636-95bb-3217ef867c1a"; Value=0; Name="Wireless adapter power saving: Maximum performance" }
    )

    foreach ($item in $settings) {
        try {
            powercfg /setacvalueindex SCHEME_CURRENT $item.Sub $item.Set $item.Value | Out-Null
            Write-Host "Applied: $($item.Name)"
        }
        catch { Write-Host "Skipped unsupported power setting: $($item.Name)" -ForegroundColor DarkYellow }
    }
    powercfg /setactive SCHEME_CURRENT | Out-Null
    Configure-PowerForServer
}

function Configure-FirewallBaseline {
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
    Write-Host "Windows Firewall enabled for Domain, Private, and Public profiles."
}

function Configure-FirewallDefaultInboundBlock {
    Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultInboundAction Block -DefaultOutboundAction Allow
    $exportPath = "$Root\backups\firewall-rules-$(Get-Date -Format yyyy-MM-dd_HH-mm).wfw"
    netsh advfirewall export "$exportPath" | Out-Null
    Write-Host "Firewall default inbound action is Block. Exported firewall rules to: $exportPath"
}

function Configure-PrivateNetworkProfile {
    try {
        $profiles = Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne "DomainAuthenticated" }
        foreach ($profile in $profiles) {
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private
            Write-Host "Set network profile '$($profile.Name)' to Private."
        }
    }
    catch { Write-Host "Could not change network profile. You can do this manually in Windows Settings." -ForegroundColor DarkYellow }
}

function Configure-WindowsUpdateActiveHours {
    $wuPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    New-Item -Path $wuPath -Force | Out-Null
    New-ItemProperty -Path $wuPath -Name ActiveHoursStart -Value 6 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $wuPath -Name ActiveHoursEnd -Value 2 -PropertyType DWord -Force | Out-Null
    Write-Host "Windows Update active hours set to 06:00-02:00, leaving roughly 02:00-06:00 as a maintenance window."
}

function Get-PrimaryNetworkInfo {
    $configs = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } | Select-Object -First 1
    if (-not $configs) { return $null }
    $adapter = Get-NetAdapter -InterfaceIndex $configs.InterfaceIndex -ErrorAction SilentlyContinue
    [pscustomobject]@{
        InterfaceAlias = $configs.InterfaceAlias
        InterfaceIndex = $configs.InterfaceIndex
        IPAddress = $configs.IPv4Address.IPAddress
        PrefixLength = $configs.IPv4Address.PrefixLength
        Gateway = $configs.IPv4DefaultGateway.NextHop
        DnsServers = ($configs.DNSServer.ServerAddresses -join ", ")
        MacAddress = if ($adapter) { $adapter.MacAddress } else { "Unknown" }
    }
}

function Get-SuggestedReservedIP([string]$IP, [string]$Gateway) {
    try {
        $parts = $Gateway.Split('.')
        if ($parts.Count -eq 4) {
            $suggestedLast = 50
            $ipLast = [int]($IP.Split('.')[-1])
            if ($ipLast -eq 50) { $suggestedLast = 51 }
            return "$($parts[0]).$($parts[1]).$($parts[2]).$suggestedLast"
        }
    } catch {}
    return $IP
}

function Generate-RouterBiosChecklist {
    $info = Get-PrimaryNetworkInfo
    $out = "$Root\reports\Router-BIOS-Checklist.txt"
    if (-not $info) {
        Write-TextFile $out "Could not detect a primary network adapter with a gateway. Connect Ethernet and rerun this option."
        Write-Host "Checklist written to: $out"
        return
    }
    $suggested = Get-SuggestedReservedIP -IP $info.IPAddress -Gateway $info.Gateway
    $content = @"
Home Server Router / BIOS Checklist
Generated: $(Get-Date)

PC name: $env:COMPUTERNAME
Current user: $env:USERNAME
Interface: $($info.InterfaceAlias)
MAC address for router DHCP reservation: $($info.MacAddress)
Current IPv4 address: $($info.IPAddress)
Gateway / router address: $($info.Gateway)
DNS servers: $($info.DnsServers)
Suggested reserved IP: $suggested

Router tasks:
1. Log in to your router admin page, usually http://$($info.Gateway)
2. Find DHCP reservation / address reservation / LAN devices.
3. Reserve this MAC address: $($info.MacAddress)
4. Reserve IP address: $suggested
5. Save, then reboot the mini PC or renew DHCP.

BIOS/UEFI tasks:
1. Reboot and enter BIOS/UEFI setup.
2. Look for Power Management / AC Recovery.
3. Enable one of these, depending on your BIOS wording:
   - Restore on AC Power Loss: Power On
   - AC Back: Always On
   - After Power Failure: Power On
4. Optional: enable Wake on LAN.
5. Save and exit.

Networking advice:
- Prefer Ethernet over Wi-Fi.
- Prefer Tailscale/WireGuard/Cloudflare Tunnel over direct port forwarding.
- Do not expose Remote Desktop directly to the internet.
"@
    Write-TextFile $out $content
    Write-Host "Checklist written to: $out"
}

function Configure-StaticIPWizard {
    Write-Host "This changes Windows networking. Router DHCP reservation is safer for most users." -ForegroundColor Yellow
    if (-not (Confirm-Choice "Continue with Windows static IP setup?" $false)) { return }

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Sort-Object InterfaceIndex
    $adapters | Select-Object InterfaceIndex, Name, InterfaceDescription, MacAddress | Format-Table -AutoSize
    $indexText = Read-Host "InterfaceIndex to configure"
    if (-not ($indexText -as [int])) { Write-Host "Invalid InterfaceIndex." -ForegroundColor Red; return }
    $adapter = $adapters | Where-Object { $_.InterfaceIndex -eq [int]$indexText } | Select-Object -First 1
    if (-not $adapter) { Write-Host "No active adapter matched that InterfaceIndex." -ForegroundColor Red; return }

    $current = Get-NetIPConfiguration -InterfaceIndex $adapter.InterfaceIndex
    $currentIP = if ($current.IPv4Address) { $current.IPv4Address.IPAddress } else { "192.168.1.50" }
    $currentPrefix = if ($current.IPv4Address) { [string]$current.IPv4Address.PrefixLength } else { "24" }
    $currentGateway = if ($current.IPv4DefaultGateway) { $current.IPv4DefaultGateway.NextHop } else { "192.168.1.1" }

    $ip = Read-Default "Static IPv4 address" $currentIP
    $prefix = [int](Read-Default "Prefix length" $currentPrefix)
    $gateway = Read-Default "Default gateway" $currentGateway
    $dns = Read-Default "DNS servers separated by commas" "1.1.1.1,8.8.8.8"

    $revert = @"
# Revert network adapter to DHCP.
# Generated by HomeServerSetupWizard.
`$alias = "$($adapter.Name)"
Set-NetIPInterface -InterfaceAlias `$alias -Dhcp Enabled
Set-DnsClientServerAddress -InterfaceAlias `$alias -ResetServerAddresses
Write-Host "Reverted `$alias to DHCP. Reconnect the network if needed."
"@
    Write-TextFile "$Root\scripts\Revert-Network-To-DHCP.ps1" $revert

    if (-not (Confirm-Choice "Apply static IP $ip/$prefix gateway $gateway to '$($adapter.Name)'?" $false)) { return }

    Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -ne "WellKnown" } | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ip -PrefixLength $prefix -DefaultGateway $gateway | Out-Null
    $dnsArray = $dns.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsArray
    Write-Host "Static IP applied. Revert script: $Root\scripts\Revert-Network-To-DHCP.ps1"
}

function Create-DockerTemplates {
    $dockerDir = "$Root\templates\docker"
    New-Item -ItemType Directory -Path $dockerDir -Force | Out-Null

    $compose = @"
# Starter Docker Compose file.
# Save a copy in C:\HomeServer\apps\your-app\docker-compose.yml.
# Run with: docker compose up -d

services:
  myapp:
    image: your/image:latest
    container_name: myapp
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - C:/HomeServer/data/myapp:/data
    environment:
      - TZ=Europe/London
"@
    Write-TextFile "$dockerDir\docker-compose.example.yml" $compose

    $envTemplate = @"
# Example .env template. Do not publish real secrets.
TZ=Europe/London
PUID=1000
PGID=1000
"@
    Write-TextFile "$dockerDir\.env.example" $envTemplate

    $dockerReadme = @"
# Docker templates

1. Install Docker Desktop.
2. Copy docker-compose.example.yml into C:\HomeServer\apps\APPNAME\docker-compose.yml.
3. Edit ports, volumes, and environment variables.
4. Run:

   cd C:\HomeServer\apps\APPNAME
   docker compose up -d

Use restart: unless-stopped for apps that should survive reboots.
"@
    Write-TextFile "$dockerDir\README.md" $dockerReadme
}

function Create-ReverseProxyTemplates {
    $base = "$Root\templates\reverse-proxy"
    New-Item -ItemType Directory -Path $base -Force | Out-Null

    $caddyCompose = @"
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - C:/HomeServer/templates/reverse-proxy/caddy/Caddyfile:/etc/caddy/Caddyfile
      - C:/HomeServer/data/caddy/data:/data
      - C:/HomeServer/data/caddy/config:/config
"@
    Write-TextFile "$base\caddy\docker-compose.yml" $caddyCompose

    $caddyFile = @"
# Local example. Replace with your domain/app details.
# For local-only use, keep this behind Tailscale/VPN.

:8088 {
    respond "Caddy is running from HomeServer"
}

# Example app reverse proxy:
# app.yourdomain.com {
#     reverse_proxy host.docker.internal:3001
# }
"@
    Write-TextFile "$base\caddy\Caddyfile" $caddyFile

    $npmCompose = @"
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - C:/HomeServer/data/nginx-proxy-manager/data:/data
      - C:/HomeServer/data/nginx-proxy-manager/letsencrypt:/etc/letsencrypt
"@
    Write-TextFile "$base\nginx-proxy-manager\docker-compose.yml" $npmCompose

    $traefikCompose = @"
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --entrypoints.web.address=:80
    ports:
      - "80:80"
      - "8081:8080"
    volumes:
      - //var/run/docker.sock:/var/run/docker.sock:ro
"@
    Write-TextFile "$base\traefik\docker-compose.yml" $traefikCompose

    Write-Host "Reverse proxy templates created under: $base"
}

function Create-CloudflareTunnelTemplate {
    $dir = "$Root\templates\cloudflared"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $compose = @"
# Cloudflare Tunnel template.
# 1. Create a tunnel in the Cloudflare dashboard.
# 2. Replace YOUR_TUNNEL_TOKEN_HERE below.
# 3. Run: docker compose up -d

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token YOUR_TUNNEL_TOKEN_HERE
"@
    Write-TextFile "$dir\docker-compose.yml" $compose
    $readme = @"
# Cloudflare Tunnel template

This template cannot log in to your Cloudflare account or create a tunnel token.
Create the tunnel in Cloudflare, paste the token into docker-compose.yml, then run:

cd C:\HomeServer\templates\cloudflared
docker compose up -d

Use this for public web apps instead of router port forwarding.
"@
    Write-TextFile "$dir\README.md" $readme
}

function Create-UptimeKumaCompose {
    $dir = "$Root\apps\uptime-kuma"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $compose = @"
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - C:/HomeServer/data/uptime-kuma:/app/data
    environment:
      - TZ=Europe/London
"@
    Write-TextFile "$dir\docker-compose.yml" $compose
    Write-Host "Uptime Kuma compose file written to: $dir\docker-compose.yml"
}

function Test-DockerAvailable {
    $cmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    try { docker version | Out-Null; return $true } catch { return $false }
}

function Deploy-UptimeKuma {
    Create-UptimeKumaCompose
    if (-not (Test-DockerAvailable)) {
        Write-Host "Docker is not available/running. Template created, but not started." -ForegroundColor Yellow
        return
    }
    Push-Location "$Root\apps\uptime-kuma"
    try { docker compose up -d } finally { Pop-Location }
    if (Confirm-Choice "Open Windows Firewall TCP port 3001 on Private profile for Uptime Kuma?" $true) {
        New-NetFirewallRule -DisplayName "HomeServer - Uptime Kuma 3001" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3001 -Profile Private -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Host "Uptime Kuma should be available at: http://localhost:3001"
}

function Create-DockerAutostartScript {
    $script = @'
param(
    [string]$Root = "__ROOT__"
)

$ErrorActionPreference = "Continue"
$logDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir "docker-autostart.log"
"[$(Get-Date -Format s)] Docker autostart beginning." | Out-File $log -Append -Encoding UTF8

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    "[$(Get-Date -Format s)] Docker CLI not found." | Out-File $log -Append -Encoding UTF8
    exit 0
}

try { docker version | Out-File $log -Append -Encoding UTF8 } catch {
    "[$(Get-Date -Format s)] Docker is not ready: $($_.Exception.Message)" | Out-File $log -Append -Encoding UTF8
    exit 0
}

$composeFiles = Get-ChildItem -Path (Join-Path $Root "apps") -Recurse -File -Include "docker-compose.yml","docker-compose.yaml","compose.yml","compose.yaml" -ErrorAction SilentlyContinue
foreach ($file in $composeFiles) {
    "[$(Get-Date -Format s)] Starting compose app in $($file.DirectoryName)" | Out-File $log -Append -Encoding UTF8
    Push-Location $file.DirectoryName
    try {
        docker compose up -d 2>&1 | Out-File $log -Append -Encoding UTF8
    }
    catch {
        "[$(Get-Date -Format s)] Failed: $($_.Exception.Message)" | Out-File $log -Append -Encoding UTF8
    }
    finally { Pop-Location }
}
"[$(Get-Date -Format s)] Docker autostart finished." | Out-File $log -Append -Encoding UTF8
'@
    $script = $script.Replace("__ROOT__", $Root)
    Write-TextFile "$Root\scripts\Start-All-Docker-Apps.ps1" $script
}

function Register-DockerAutostartTask {
    Create-DockerAutostartScript
    $script = "$Root\scripts\Start-All-Docker-Apps.ps1"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName "Start All Docker Apps" -TaskPath "\HomeServer\" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Write-Host "Created logon task: HomeServer\Start All Docker Apps"
    Write-Host "Note: Docker Desktop normally needs a user session. This task runs when this user logs in."
}

function Start-AllDockerAppsNow {
    $script = "$Root\scripts\Start-All-Docker-Apps.ps1"
    if (-not (Test-Path $script)) { Create-DockerAutostartScript }
    & $script -Root $Root
    Write-Host "Docker app start attempt complete. Log: $Root\logs\docker-autostart.log"
}

function Create-MaintenanceScripts {
    Initialize-Config

    $backupScript = @'
param(
    [string]$Root = "__ROOT__",
    [string]$BackupTarget = "",
    [int]$Retention = 0
)

$ErrorActionPreference = "Stop"
$configPath = Join-Path $Root "config\homeserver.config.json"
$config = $null
if (Test-Path $configPath) { $config = Get-Content $configPath -Raw | ConvertFrom-Json }
if ([string]::IsNullOrWhiteSpace($BackupTarget)) {
    $BackupTarget = if ($config -and $config.BackupTarget) { $config.BackupTarget } else { Join-Path $Root "backups" }
}
if ($Retention -le 0) {
    $Retention = if ($config -and $config.BackupRetention) { [int]$config.BackupRetention } else { 14 }
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
New-Item -ItemType Directory -Path $BackupTarget -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Root "logs") -Force | Out-Null
$destination = Join-Path $BackupTarget "homeserver-backup-$timestamp.zip"
$manifest = Join-Path $env:TEMP "homeserver-backup-manifest-$timestamp.txt"

$paths = @(
    Join-Path $Root "data",
    Join-Path $Root "apps",
    Join-Path $Root "templates",
    Join-Path $Root "secrets",
    Join-Path $Root "config",
    Join-Path $Root "scripts"
) | Where-Object { Test-Path $_ }

if ($paths.Count -eq 0) { throw "No backup source folders were found." }

"HomeServer backup manifest" | Out-File $manifest -Encoding UTF8
"Generated: $(Get-Date)" | Out-File $manifest -Append -Encoding UTF8
"Computer: $env:COMPUTERNAME" | Out-File $manifest -Append -Encoding UTF8
"Sources:" | Out-File $manifest -Append -Encoding UTF8
$paths | ForEach-Object { "- $_" | Out-File $manifest -Append -Encoding UTF8 }

Compress-Archive -Path ($paths + $manifest) -DestinationPath $destination -Force

# Verify zip can be opened.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($destination)
try {
    if ($zip.Entries.Count -lt 1) { throw "Backup verification failed: archive has no entries." }
}
finally { $zip.Dispose() }

if ($config) {
    $config.LastBackupPath = $destination
    $config | ConvertTo-Json -Depth 8 | Out-File $configPath -Encoding UTF8
}

"[$(Get-Date -Format s)] Backup created and verified: $destination" | Out-File -FilePath (Join-Path $Root "logs\backup.log") -Append -Encoding UTF8

Get-ChildItem -Path $BackupTarget -Filter "homeserver-backup-*.zip" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip $Retention |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "Backup created and verified: $destination"
'@
    $backupScript = $backupScript.Replace("__ROOT__", $Root)
    Write-TextFile "$Root\scripts\Backup-HomeServer.ps1" $backupScript

    $restoreScript = @'
param(
    [string]$Root = "__ROOT__",
    [string]$BackupZip = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($BackupZip)) {
    $BackupZip = Read-Host "Full path to homeserver-backup-*.zip"
}
if (-not (Test-Path $BackupZip)) { throw "Backup file not found: $BackupZip" }

$stage = Join-Path $Root ("restore\stage-" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Expand-Archive -Path $BackupZip -DestinationPath $stage -Force
Write-Host "Backup extracted to: $stage"

Write-Host "This restore will copy extracted apps/data/templates/secrets/config/scripts into $Root." -ForegroundColor Yellow
if (-not $Force) {
    $answer = Read-Host "Type RESTORE to continue"
    if ($answer -ne "RESTORE") { Write-Host "Restore cancelled."; exit 0 }
}

$names = @("data","apps","templates","secrets","config","scripts")
foreach ($name in $names) {
    $source = Join-Path $stage $name
    if (Test-Path $source) {
        $dest = Join-Path $Root $name
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item -Path (Join-Path $source "*") -Destination $dest -Recurse -Force
        Write-Host "Restored: $name"
    }
}
Write-Host "Restore complete. Review configs/secrets before starting apps."
'@
    $restoreScript = $restoreScript.Replace("__ROOT__", $Root)
    Write-TextFile "$Root\scripts\Restore-HomeServer.ps1" $restoreScript

    $healthScript = @'
param(
    [string]$Root = "__ROOT__"
)

$ErrorActionPreference = "Continue"
$configPath = Join-Path $Root "config\homeserver.config.json"
$config = $null
if (Test-Path $configPath) { $config = Get-Content $configPath -Raw | ConvertFrom-Json }
$logDir = Join-Path $Root "logs"
$dashDir = Join-Path $Root "dashboard"
New-Item -ItemType Directory -Path $logDir,$dashDir -Force | Out-Null
$report = Join-Path $logDir "health-report.txt"
$statusJson = Join-Path $dashDir "status.json"
$issues = New-Object System.Collections.Generic.List[string]

function Add-Line($text="") { $text | Out-File $report -Append -Encoding UTF8 }
function Send-HomeServerAlert([string]$Title, [string]$Message) {
    if (-not $config -or $config.AlertProvider -eq "none") { return }
    try {
        switch ($config.AlertProvider) {
            "discord" {
                if ($config.DiscordWebhookUrl) { Invoke-RestMethod -Method Post -Uri $config.DiscordWebhookUrl -ContentType "application/json" -Body (@{ content = "**$Title**`n$Message" } | ConvertTo-Json) | Out-Null }
            }
            "telegram" {
                if ($config.TelegramBotToken -and $config.TelegramChatId) {
                    $uri = "https://api.telegram.org/bot$($config.TelegramBotToken)/sendMessage"
                    Invoke-RestMethod -Method Post -Uri $uri -Body @{ chat_id = $config.TelegramChatId; text = "$Title`n$Message" } | Out-Null
                }
            }
            "ntfy" {
                if ($config.NtfyTopic) { Invoke-RestMethod -Method Post -Uri "https://ntfy.sh/$($config.NtfyTopic)" -Body "$Title`n$Message" | Out-Null }
            }
            "gotify" {
                if ($config.GotifyUrl -and $config.GotifyToken) {
                    $uri = $config.GotifyUrl.TrimEnd('/') + "/message?token=$($config.GotifyToken)"
                    Invoke-RestMethod -Method Post -Uri $uri -Body @{ title = $Title; message = $Message; priority = 5 } | Out-Null
                }
            }
            "smtp" {
                if ($config.SmtpServer -and $config.SmtpFrom -and $config.SmtpTo) {
                    Send-MailMessage -SmtpServer $config.SmtpServer -Port $config.SmtpPort -UseSsl:([bool]$config.SmtpUseSsl) -From $config.SmtpFrom -To $config.SmtpTo -Subject $Title -Body $Message
                }
            }
        }
    } catch { "[$(Get-Date -Format s)] Alert failed: $($_.Exception.Message)" | Out-File (Join-Path $logDir "alert.log") -Append -Encoding UTF8 }
}

"Home Server Health Check - $(Get-Date)" | Out-File $report -Encoding UTF8
Add-Line
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$uptime = (Get-Date) - $os.LastBootUpTime
Add-Line "Computer: $env:COMPUTERNAME"
Add-Line "OS: $($os.Caption) $($os.Version)"
Add-Line "Uptime: $uptime"
$totalRamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
$freeRamGB = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 2)
$usedRamPct = if ($totalRamGB -gt 0) { [math]::Round((($totalRamGB - $freeRamGB) / $totalRamGB) * 100, 1) } else { 0 }
$cpuLoad = try { [int]((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average) } catch { 0 }
Add-Line "RAM: $totalRamGB GB total, $freeRamGB GB free, $usedRamPct% used"
Add-Line "CPU load sample: $cpuLoad%"
if ($usedRamPct -gt 90) { $issues.Add("High memory usage: $usedRamPct% used.") }
if ($cpuLoad -gt 90) { $issues.Add("High CPU load sample: $cpuLoad%.") }
Add-Line

Add-Line "Disk space:"
$lowPercent = if ($config -and $config.LowDiskFreePercent) { [double]$config.LowDiskFreePercent } else { 15 }
$lowGB = if ($config -and $config.LowDiskFreeGB) { [double]$config.LowDiskFreeGB } else { 10 }
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freeGB = [math]::Round($_.FreeSpace / 1GB, 2)
    $sizeGB = [math]::Round($_.Size / 1GB, 2)
    $pct = if ($sizeGB -gt 0) { [math]::Round(($freeGB / $sizeGB) * 100, 1) } else { 0 }
    if ($pct -lt $lowPercent -or $freeGB -lt $lowGB) { $issues.Add("Low disk space on $($_.DeviceID): $freeGB GB free ($pct%).") }
    [pscustomobject]@{ Drive=$_.DeviceID; FreeGB=$freeGB; SizeGB=$sizeGB; FreePercent=$pct }
}
$disks | Format-Table -AutoSize | Out-String | Out-File $report -Append -Encoding UTF8

Add-Line "Network addresses:"
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv6Address, DNSServer | Format-List | Out-String | Out-File $report -Append -Encoding UTF8

Add-Line "Firewall profiles:"
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize | Out-String | Out-File $report -Append -Encoding UTF8

Add-Line "Disk health:"
try {
    Get-PhysicalDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus, Size, MediaType | Format-Table -AutoSize | Out-String | Out-File $report -Append -Encoding UTF8
    Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne "Healthy" } | ForEach-Object { $issues.Add("Physical disk not healthy: $($_.FriendlyName) $($_.HealthStatus)") }
} catch { Add-Line "Physical disk health not available: $($_.Exception.Message)" }

Add-Line "HomeServer scheduled tasks:"
try { Get-ScheduledTask -TaskPath "\HomeServer\" | Select-Object TaskName, State | Format-Table -AutoSize | Out-String | Out-File $report -Append -Encoding UTF8 } catch { Add-Line "No HomeServer scheduled tasks found." }

Add-Line "Docker containers:"
$dockerRows = @()
try {
    $dockerText = docker ps -a --format "{{.Names}}|{{.Status}}|{{.Ports}}" 2>$null
    if ($dockerText) {
        foreach ($line in $dockerText) {
            $parts = $line -split "\|", 3
            $dockerRows += [pscustomobject]@{ Name=$parts[0]; Status=$parts[1]; Ports=if($parts.Count -gt 2){$parts[2]}else{""} }
            if ($parts[1] -match "Exited|Dead|Restarting") { $issues.Add("Docker container needs attention: $($parts[0]) $($parts[1])") }
        }
        $dockerRows | Format-Table -AutoSize | Out-String | Out-File $report -Append -Encoding UTF8
    } else { Add-Line "No Docker containers returned." }
} catch { Add-Line "Docker not available or not running." }


Add-Line "Desktop Server Apps:"
$desktopRows = @()
try {
    $manifestDir = Join-Path $Root "config\desktop-apps"
    if (Test-Path $manifestDir) {
        Get-ChildItem -Path $manifestDir -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            $manifestFileName = $_.Name
            $m = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $names = @($m.ProcessNames) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            $running = $false
            $runningNames = @()
            foreach ($name in $names) {
                $found = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
                if ($found.Count -gt 0) { $running = $true; $runningNames += $name }
            }
            $watchdog = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*Run-DesktopServerApp-Watchdog.ps1*" -and $_.CommandLine -like "*$manifestFileName*" })
            $watchdogState = if ($watchdog.Count -gt 0) { "watchdog running" } else { "watchdog not detected" }
            if ($names.Count -eq 0) { $running = ($watchdog.Count -gt 0) }
            $state = if ($running) { "Running" } elseif ($m.Enabled -eq $false) { "Disabled" } else { "Not detected" }
            if ($state -eq "Not detected") { $issues.Add("Desktop Server App not detected: $($m.Name)") }
            $desktopRows += [pscustomobject]@{ Name=$m.Name; State=$state; Watchdog=$watchdogState; Launcher=$m.StartFile }
        }
        if ($desktopRows.Count -gt 0) { $desktopRows | Format-Table -AutoSize | Out-String | Out-File $report -Append -Encoding UTF8 } else { Add-Line "No approved Desktop Server Apps found." }
    } else { Add-Line "Desktop Server Apps manifest folder not found." }
} catch { Add-Line "Desktop Server Apps status failed: $($_.Exception.Message)" }

Add-Line "Backup status:"
$backupTarget = if ($config -and $config.BackupTarget) { $config.BackupTarget } else { Join-Path $Root "backups" }
$lastBackup = Get-ChildItem -Path $backupTarget -Filter "homeserver-backup-*.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($lastBackup) {
    Add-Line "Last backup: $($lastBackup.FullName) at $($lastBackup.LastWriteTime)"
    if ($lastBackup.LastWriteTime -lt (Get-Date).AddDays(-2)) { $issues.Add("Last backup is older than 2 days: $($lastBackup.LastWriteTime)") }
} else {
    Add-Line "No backups found in $backupTarget"
    $issues.Add("No HomeServer backups found in $backupTarget")
}

$status = [ordered]@{
    generatedAt = (Get-Date).ToString("s")
    computerName = $env:COMPUTERNAME
    os = "$($os.Caption) $($os.Version)"
    uptime = $uptime.ToString()
    ramGB = $totalRamGB
    freeRamGB = $freeRamGB
    usedRamPercent = $usedRamPct
    cpuLoadPercent = $cpuLoad
    disks = $disks
    docker = $dockerRows
    desktopApps = $desktopRows
    backupTarget = $backupTarget
    lastBackup = if ($lastBackup) { $lastBackup.FullName } else { "" }
    issues = $issues.ToArray()
}
$status | ConvertTo-Json -Depth 8 | Out-File $statusJson -Encoding UTF8

if ($issues.Count -gt 0) {
    Add-Line
    Add-Line "Issues:"
    $issues | ForEach-Object { Add-Line "- $_" }
    Send-HomeServerAlert -Title "HomeServer issue on $env:COMPUTERNAME" -Message ($issues -join "`n")
}

"[$(Get-Date -Format s)] Health check written to $report" | Out-File -FilePath (Join-Path $Root "logs\health-check.log") -Append -Encoding UTF8
Write-Host "Health report written to: $report"
'@
    $healthScript = $healthScript.Replace("__ROOT__", $Root)
    Write-TextFile "$Root\scripts\Health-Check.ps1" $healthScript

    $encryptedBackup = @'
param(
    [string]$Root = "__ROOT__",
    [string]$BackupTarget = ""
)

$ErrorActionPreference = "Stop"
$sevenZip = Get-Command 7z.exe -ErrorAction SilentlyContinue
if (-not $sevenZip) { $sevenZip = Get-Command 7z -ErrorAction SilentlyContinue }
if (-not $sevenZip) { throw "7-Zip CLI was not found. Install 7-Zip first." }
if ([string]::IsNullOrWhiteSpace($BackupTarget)) { $BackupTarget = Join-Path $Root "backups" }
New-Item -ItemType Directory -Path $BackupTarget -Force | Out-Null
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$out = Join-Path $BackupTarget "homeserver-encrypted-$timestamp.7z"
$secure = Read-Host "Encryption password. Save this somewhere safe; losing it means losing the backup" -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
try {
    $sources = @("data","apps","templates","secrets","config","scripts") | ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path $_ }
    & $sevenZip.Path a -t7z $out $sources -mhe=on "-p$plain"
    if ($LASTEXITCODE -ne 0) { throw "7-Zip returned exit code $LASTEXITCODE" }
    Write-Host "Encrypted backup created: $out"
}
finally {
    $plain = $null
    [GC]::Collect()
}
'@
    $encryptedBackup = $encryptedBackup.Replace("__ROOT__", $Root)
    Write-TextFile "$Root\scripts\Create-Encrypted-Backup.ps1" $encryptedBackup

    $reportScript = @'
param([string]$Root = "__ROOT__")
& (Join-Path $Root "scripts\Health-Check.ps1") -Root $Root
Get-Content (Join-Path $Root "logs\health-report.txt")
'@
    $reportScript = $reportScript.Replace("__ROOT__", $Root)
    Write-TextFile "$Root\scripts\Show-HealthReport.ps1" $reportScript

    Create-DockerAutostartScript
    Create-DashboardFiles
}

function Create-DashboardFiles {
    $html = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>HomeForge Dashboard</title>
  <style>
    body { font-family: Segoe UI, system-ui, sans-serif; margin: 0; background: #0f172a; color: #e5e7eb; }
    header { padding: 24px; background: #111827; border-bottom: 1px solid #334155; }
    main { padding: 24px; display: grid; gap: 16px; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); }
    .card { background: #111827; border: 1px solid #334155; border-radius: 16px; padding: 18px; box-shadow: 0 10px 24px rgba(0,0,0,.25); }
    h1 { margin: 0 0 6px; font-size: 28px; }
    h2 { margin-top: 0; font-size: 18px; color: #93c5fd; }
    .ok { color: #86efac; }
    .bad { color: #fca5a5; }
    table { width: 100%; border-collapse: collapse; }
    td, th { border-bottom: 1px solid #334155; padding: 8px; text-align: left; }
    code { color: #fde68a; }
  </style>
</head>
<body>
<header>
  <h1>HomeForge Dashboard</h1>
  <div id="generated">Loading status.json...</div>
</header>
<main>
  <section class="card"><h2>Server</h2><div id="server"></div></section>
  <section class="card"><h2>Issues</h2><div id="issues"></div></section>
  <section class="card"><h2>Disks</h2><div id="disks"></div></section>
  <section class="card"><h2>Docker</h2><div id="docker"></div></section>
  <section class="card"><h2>Desktop Server Apps</h2><div id="desktopApps"></div></section>
  <section class="card"><h2>Backups</h2><div id="backups"></div></section>
  <section class="card"><h2>Useful paths</h2><p><code>C:\HomeServer\logs\health-report.txt</code></p><p><code>C:\HomeServer\scripts</code></p></section>
</main>
<script>
async function load() {
  try {
    const res = await fetch('status.json?ts=' + Date.now());
    const s = await res.json();
    document.getElementById('generated').textContent = 'Generated: ' + s.generatedAt;
    document.getElementById('server').innerHTML = `<p><b>${s.computerName}</b></p><p>${s.os}</p><p>Uptime: ${s.uptime}</p><p>RAM: ${s.ramGB} GB</p>`;
    document.getElementById('issues').innerHTML = s.issues && s.issues.length ? '<ul>' + s.issues.map(i => `<li class="bad">${i}</li>`).join('') + '</ul>' : '<p class="ok">No issues reported.</p>';
    document.getElementById('disks').innerHTML = table(s.disks || [], ['Drive','FreeGB','SizeGB','FreePercent']);
    document.getElementById('docker').innerHTML = table(s.docker || [], ['Name','Status','Ports']);
    document.getElementById('desktopApps').innerHTML = table(s.desktopApps || [], ['Name','State','Watchdog','Launcher']);
    document.getElementById('backups').innerHTML = `<p>Target: <code>${s.backupTarget || ''}</code></p><p>Last: <code>${s.lastBackup || 'none'}</code></p>`;
  } catch (e) {
    document.getElementById('generated').textContent = 'Could not load status.json. Run C:\\HomeServer\\scripts\\Health-Check.ps1 first.';
  }
}
function table(rows, keys) {
  if (!rows.length) return '<p>No data.</p>';
  return '<table><thead><tr>' + keys.map(k => `<th>${k}</th>`).join('') + '</tr></thead><tbody>' +
    rows.map(r => '<tr>' + keys.map(k => `<td>${r[k] ?? ''}</td>`).join('') + '</tr>').join('') + '</tbody></table>';
}
load();
setInterval(load, 60000);
</script>
</body>
</html>
'@
    Write-TextFile "$Root\dashboard\index.html" $html
}

function Register-MaintenanceTasks {
    $backupScript = "$Root\scripts\Backup-HomeServer.ps1"
    $healthScript = "$Root\scripts\Health-Check.ps1"
    if (-not (Test-Path $backupScript) -or -not (Test-Path $healthScript)) { Create-MaintenanceScripts }

    schtasks /Create /TN "\HomeServer\Daily Backup" /SC DLY /ST 03:00 /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$backupScript`"" /RU SYSTEM /RL HIGHEST /F | Out-Null
    schtasks /Create /TN "\HomeServer\Health Check" /SC MINUTE /MO 15 /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$healthScript`"" /RU SYSTEM /RL HIGHEST /F | Out-Null

    Write-Host "Created scheduled task: HomeServer\Daily Backup at 03:00."
    Write-Host "Created scheduled task: HomeServer\Health Check every 15 minutes."
}

function Configure-BackupTargetWizard {
    $cfg = Get-HomeServerConfig
    $target = Read-Default "Backup target path, e.g. D:\HomeServerBackups or \\NAS\Backups\MiniPC" $cfg.BackupTarget
    $retention = [int](Read-Default "How many backup zip files to keep" ([string]$cfg.BackupRetention))
    try { New-Item -ItemType Directory -Path $target -Force | Out-Null } catch { Write-Host "Could not create target. Network paths may require credentials." -ForegroundColor Yellow }
    $cfg.BackupTarget = $target
    $cfg.BackupRetention = $retention
    Save-HomeServerConfig $cfg
    Create-MaintenanceScripts
    Register-MaintenanceTasks
    Write-Host "Backup target saved: $target"
}

function Register-CustomStartupApp {
    $taskName = Read-Host "Task name, e.g. My Bot"
    $command = Read-Host "Full command or script path to run"
    if ([string]::IsNullOrWhiteSpace($taskName) -or [string]::IsNullOrWhiteSpace($command)) {
        Write-Host "Task name and command are required." -ForegroundColor Red
        return
    }

    $safeName = $taskName -replace '[^a-zA-Z0-9._ -]', '_'
    $taskFolder = "$Root\apps\$safeName"
    New-Item -ItemType Directory -Path $taskFolder -Force | Out-Null
    $launcher = Join-Path $taskFolder "start.bat"
    $launcherContent = @"
@echo off
cd /d "$taskFolder"
$command
"@
    $launcherContent | Out-File -FilePath $launcher -Encoding ASCII

    $action = New-ScheduledTaskAction -Execute $launcher
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -TaskPath "\HomeServer\" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Write-Host "Created startup task with crash recovery: HomeServer\$taskName"
    Write-Host "Launcher written to: $launcher"
}


function Get-SafeName([string]$Name) {
    $safe = $Name -replace '[^a-zA-Z0-9._ -]', '_'
    $safe = $safe.Trim()
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = "App" }
    return $safe
}

function Get-DesktopServerAppsFolder {
    $cfg = Get-HomeServerConfig
    if ($cfg.PSObject.Properties.Name -contains "DesktopAppsFolder" -and -not [string]::IsNullOrWhiteSpace($cfg.DesktopAppsFolder)) {
        return [string]$cfg.DesktopAppsFolder
    }
    return (Join-Path ([Environment]::GetFolderPath("Desktop")) "Home Server Apps")
}

function Harden-SecretsFolder {
    $secretFolders = @(
        (Join-Path $Root "secrets"),
        (Join-Path $Root "secrets\desktop-apps")
    )
    foreach ($path in $secretFolders) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        try {
            $acl = Get-Acl $path
            $acl.SetAccessRuleProtection($true, $false)
            $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
            $current = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            $admins = (New-Object Security.Principal.SecurityIdentifier("S-1-5-32-544")).Translate([Security.Principal.NTAccount]).Value
            $system = "NT AUTHORITY\SYSTEM"
            foreach ($identity in @($current, $admins, $system)) {
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $acl.AddAccessRule($rule)
            }
            Set-Acl -Path $path -AclObject $acl
        } catch {
            Write-Host "Could not harden permissions on $path: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

function Create-DesktopServerAppsFolder {
    $cfg = Get-HomeServerConfig
    $desktopFolder = Get-DesktopServerAppsFolder
    New-Item -ItemType Directory -Path $desktopFolder -Force | Out-Null
    New-Item -ItemType Directory -Path "$Root\config\desktop-apps", "$Root\data\desktop-apps", "$Root\secrets\desktop-apps", "$Root\logs\desktop-apps", "$Root\reports" -Force | Out-Null
    Harden-SecretsFolder

    $readme = @"
# Home Server Apps drop-zone

Put portable Windows server apps here if you want the Home Server wizard to keep them running.

## Beginner-friendly layout

Desktop\Home Server Apps\
  My Discord Bot\
    start.bat
    bot.exe
    config files

  My Game Server\
    server.exe
    server.properties

## Important safety rule

HomeForge will NOT blindly run every .exe by itself.
Run HomeForge option "Scan/register Desktop Server Apps" and approve the launcher for each app.

## Best practice

For each app folder, create one of these files if you can:

- start.bat
- run.bat
- launch.bat
- server.bat
- start.ps1

HomeForge prefers those files because they make it clear what should run.

## Secure storage created by HomeForge

For each approved app, HomeForge creates:

- Data:    C:\HomeServer\data\desktop-apps\APPNAME
- Logs:    C:\HomeServer\logs\desktop-apps\APPNAME
- Secrets: C:\HomeServer\secrets\desktop-apps\APPNAME

The watchdog sets these environment variables for your app:

- HOMESERVER_APP_NAME
- HOMESERVER_APP_FOLDER
- HOMESERVER_APP_DATA
- HOMESERVER_APP_LOGS
- HOMESERVER_APP_SECRETS

Apps only use those folders if the app supports custom data/config paths, but HomeForge creates them for cleaner organisation.

## How to make an app always-on

1. Put the app in its own subfolder here.
2. Run HomeServerSetupWizard as administrator.
3. Choose "Scan/register Desktop Server Apps".
4. Approve the correct launcher.
5. HomeForge creates a watchdog task that starts it at login and restarts it after crashes.

Created by HomeForge v$Script:Version.
"@
    Write-TextFile (Join-Path $desktopFolder "README-FIRST.txt") $readme

    $exampleFolder = Join-Path $desktopFolder "_Example App Folder"
    New-Item -ItemType Directory -Path $exampleFolder -Force | Out-Null
    $exampleStart = @"
@echo off
REM Replace this file with the command that starts your app.
REM Example:
REM cd /d "%~dp0"
REM my-server.exe

echo This is only an example. Edit start.bat to launch your real app.
pause
"@
    Write-TextFile (Join-Path $exampleFolder "start.bat") $exampleStart

    $cfg.DesktopAppsFolder = $desktopFolder
    Save-HomeServerConfig $cfg
    Write-Host "Desktop Server Apps folder ready: $desktopFolder"
}

function Create-DesktopAppWatchdogScript {
    $script = @'
param(
    [Parameter(Mandatory=$true)]
    [string]$ManifestPath
)

$ErrorActionPreference = "Continue"
if (-not (Test-Path $ManifestPath)) { throw "Manifest not found: $ManifestPath" }

function Read-Manifest {
    return (Get-Content $ManifestPath -Raw | ConvertFrom-Json)
}

function Write-WatchdogLog([string]$Message) {
    $m = Read-Manifest
    $logDir = if ($m.LogsPath) { $m.LogsPath } else { Join-Path (Split-Path $ManifestPath -Parent) "logs" }
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $log = Join-Path $logDir ("watchdog-" + (Get-Date -Format "yyyy-MM-dd") + ".log")
    "[$(Get-Date -Format s)] $Message" | Out-File -FilePath $log -Append -Encoding UTF8
}

Write-WatchdogLog "Watchdog starting for manifest: $ManifestPath"
while ($true) {
    $manifest = Read-Manifest
    if ($manifest.Enabled -eq $false) {
        Write-WatchdogLog "App is disabled in manifest. Watchdog exiting."
        break
    }

    if (-not (Test-Path $manifest.StartFile)) {
        Write-WatchdogLog "Start file missing: $($manifest.StartFile). Retrying in 30 seconds."
        Start-Sleep -Seconds 30
        continue
    }

    New-Item -ItemType Directory -Path $manifest.DataPath, $manifest.LogsPath, $manifest.SecretsPath -Force | Out-Null
    $env:HOMESERVER_APP_NAME = $manifest.Name
    $env:HOMESERVER_APP_FOLDER = $manifest.AppFolder
    $env:HOMESERVER_APP_DATA = $manifest.DataPath
    $env:HOMESERVER_APP_LOGS = $manifest.LogsPath
    $env:HOMESERVER_APP_SECRETS = $manifest.SecretsPath

    $ext = [IO.Path]::GetExtension([string]$manifest.StartFile).ToLowerInvariant()
    $file = [string]$manifest.StartFile
    $args = [string]$manifest.StartArguments
    if ($ext -eq ".ps1") {
        $file = "powershell.exe"
        $args = "-NoProfile -ExecutionPolicy Bypass -File `"$($manifest.StartFile)`" $args"
    } elseif ($ext -eq ".bat" -or $ext -eq ".cmd") {
        $file = "cmd.exe"
        $args = "/c `"$($manifest.StartFile)`" $args"
    }

    try {
        Write-WatchdogLog "Starting: $file $args"
        $proc = Start-Process -FilePath $file -ArgumentList $args -WorkingDirectory $manifest.WorkingDirectory -PassThru

        $names = @($manifest.ProcessNames) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($names.Count -gt 0) {
            Write-WatchdogLog "Monitoring process names: $($names -join ', ')"
            Start-Sleep -Seconds 5
            while ($true) {
                $running = @()
                foreach ($name in $names) {
                    $running += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
                }
                if ($running.Count -lt 1) { break }
                Start-Sleep -Seconds 15
            }
        } else {
            Wait-Process -Id $proc.Id -ErrorAction SilentlyContinue
        }

        Write-WatchdogLog "App process ended or is no longer detected."
    } catch {
        Write-WatchdogLog "Launch or monitor error: $($_.Exception.Message)"
    }

    $delay = if ($manifest.RestartDelaySeconds) { [int]$manifest.RestartDelaySeconds } else { 10 }
    if ($delay -lt 3) { $delay = 3 }
    Write-WatchdogLog "Restarting in $delay seconds."
    Start-Sleep -Seconds $delay
}
'@
    Write-TextFile "$Root\scripts\Run-DesktopServerApp-Watchdog.ps1" $script
}

function Create-DesktopAppsScanScript {
    $script = @'
param([string]$Root = "__ROOT__")

$configPath = Join-Path $Root "config\homeserver.config.json"
$config = $null
if (Test-Path $configPath) { $config = Get-Content $configPath -Raw | ConvertFrom-Json }
$desktopFolder = if ($config -and $config.DesktopAppsFolder) { $config.DesktopAppsFolder } else { Join-Path ([Environment]::GetFolderPath("Desktop")) "Home Server Apps" }
New-Item -ItemType Directory -Path (Join-Path $Root "reports") -Force | Out-Null
$out = Join-Path $Root "reports\Desktop-Server-Apps-Inventory.csv"

$rows = @()
if (Test-Path $desktopFolder) {
    $dirs = Get-ChildItem -Path $desktopFolder -Directory -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.StartsWith("_") }
    foreach ($dir in $dirs) {
        $safe = ($dir.Name -replace '[^a-zA-Z0-9._ -]', '_').Trim()
        $manifest = Join-Path $Root "config\desktop-apps\$safe.json"
        $preferred = @("start.bat","run.bat","launch.bat","server.bat","start.cmd","run.cmd","start.ps1","run.ps1") | Where-Object { Test-Path (Join-Path $dir.FullName $_) }
        $exeCount = @(Get-ChildItem -Path $dir.FullName -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '(?i)unins|uninstall|setup|install|update|crash|helper|redist|vcredist|dxsetup' }).Count
        $approved = Test-Path $manifest
        $status = if ($approved) { "Approved" } elseif ($preferred.Count -gt 0 -or $exeCount -gt 0) { "Needs approval" } else { "No launcher found" }
        $rows += [pscustomobject]@{ Name=$dir.Name; Folder=$dir.FullName; PreferredLaunchers=($preferred -join ', '); ExeCount=$exeCount; Approved=$approved; Status=$status }
    }
}
$rows | Export-Csv -NoTypeInformation -Path $out -Encoding UTF8
Write-Host "Desktop app inventory written to: $out"
'@
    $script = $script.Replace("__ROOT__", $Root)
    Write-TextFile "$Root\scripts\Scan-DesktopServerApps.ps1" $script
}

function Register-DesktopAppsScanTask {
    Create-DesktopAppsScanScript
    $script = "$Root\scripts\Scan-DesktopServerApps.ps1"
    schtasks /Create /TN "\HomeServer\Scan Desktop Server Apps" /SC HOURLY /MO 1 /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`"" /RU SYSTEM /RL HIGHEST /F | Out-Null
    Write-Host "Created scheduled task: HomeServer\Scan Desktop Server Apps"
}

function Get-DesktopAppLauncherCandidates([string]$AppFolder) {
    $candidates = New-Object System.Collections.Generic.List[object]
    $preferred = @("start.bat","run.bat","launch.bat","server.bat","start.cmd","run.cmd","start.ps1","run.ps1")
    foreach ($name in $preferred) {
        $p = Join-Path $AppFolder $name
        if (Test-Path $p) { $candidates.Add([pscustomobject]@{ Path=(Resolve-Path $p).Path; Reason="preferred launcher" }) }
    }
    $exes = Get-ChildItem -Path $AppFolder -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '(?i)unins|uninstall|setup|install|update|crash|helper|redist|vcredist|dxsetup' } |
        Select-Object -First 30
    foreach ($exe in $exes) { $candidates.Add([pscustomobject]@{ Path=$exe.FullName; Reason="exe candidate" }) }
    return @($candidates)
}

function Register-DesktopServerAppFolder([string]$AppFolder) {
    Create-DesktopAppWatchdogScript
    $appName = Split-Path $AppFolder -Leaf
    if ([string]::IsNullOrWhiteSpace($appName) -or $appName.StartsWith("_")) { return }
    $safeName = Get-SafeName $appName
    $manifestDir = "$Root\config\desktop-apps"
    New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
    $manifestPath = Join-Path $manifestDir "$safeName.json"

    if (Test-Path $manifestPath) {
        if (-not (Confirm-Choice "App '$appName' is already approved. Re-register/update it?" $false)) { return }
    }

    $candidates = @(Get-DesktopAppLauncherCandidates -AppFolder $AppFolder)
    if ($candidates.Count -lt 1) {
        Write-Host "No obvious launcher found for $appName. Add start.bat or run.bat inside that folder, then scan again." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "App folder: $AppFolder" -ForegroundColor Cyan
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host ("{0}. {1}  [{2}]" -f ($i + 1), $candidates[$i].Path, $candidates[$i].Reason)
    }
    if ($candidates.Count -gt 1) {
        Write-Host "A. Create a start-all-approved.bat that launches all listed .exe files"
    }
    Write-Host "S. Skip this app"

    $selection = if ($candidates.Count -eq 1) {
        if (Confirm-Choice "Approve this launcher for '$appName'? $($candidates[0].Path)" $true) { "1" } else { "S" }
    } else {
        Read-Host "Choose launcher number, A for all EXEs, or S to skip"
    }

    if ($selection.Trim().ToLowerInvariant() -eq "s") { return }
    $startFile = $null
    if ($selection.Trim().ToLowerInvariant() -eq "a") {
        $exeFiles = @($candidates | Where-Object { [IO.Path]::GetExtension($_.Path).ToLowerInvariant() -eq ".exe" })
        if ($exeFiles.Count -lt 1) { Write-Host "No exe files available for start-all." -ForegroundColor Yellow; return }
        $startAll = Join-Path $AppFolder "start-all-approved.bat"
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add("@echo off")
        $lines.Add('cd /d "%~dp0"')
        foreach ($exe in $exeFiles) { $lines.Add("start `"`" `"$($exe.Path)`"") }
        $lines | Out-File -FilePath $startAll -Encoding ASCII
        $startFile = $startAll
    } else {
        $index = 0
        if (-not [int]::TryParse($selection, [ref]$index)) { Write-Host "Invalid selection." -ForegroundColor Red; return }
        if ($index -lt 1 -or $index -gt $candidates.Count) { Write-Host "Invalid selection." -ForegroundColor Red; return }
        $startFile = $candidates[$index - 1].Path
    }

    $args = Read-Default "Optional command-line arguments for this app" ""
    $processNameDefault = if ([IO.Path]::GetExtension($startFile).ToLowerInvariant() -eq ".exe") { [IO.Path]::GetFileNameWithoutExtension($startFile) } else { "" }
    $processNamesText = Read-Default "Optional process names to monitor, comma-separated. Leave blank for normal wait mode" $processNameDefault
    $processNames = @($processNamesText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    $dataPath = "$Root\data\desktop-apps\$safeName"
    $logsPath = "$Root\logs\desktop-apps\$safeName"
    $secretsPath = "$Root\secrets\desktop-apps\$safeName"
    New-Item -ItemType Directory -Path $dataPath, $logsPath, $secretsPath -Force | Out-Null
    Harden-SecretsFolder
    Write-TextFile (Join-Path $secretsPath ".env.example") "# Put secrets for $appName here if the app supports .env files.`n# Do not publish this folder.`n"

    $cfg = Get-HomeServerConfig
    $restartDelay = if ($cfg.DesktopAppRestartDelaySeconds) { [int]$cfg.DesktopAppRestartDelaySeconds } else { 10 }
    $manifest = [ordered]@{
        Name = $appName
        SafeName = $safeName
        Enabled = $true
        Approved = $true
        AppFolder = (Resolve-Path $AppFolder).Path
        WorkingDirectory = (Resolve-Path $AppFolder).Path
        StartFile = (Resolve-Path $startFile).Path
        StartArguments = $args
        ProcessNames = $processNames
        DataPath = $dataPath
        LogsPath = $logsPath
        SecretsPath = $secretsPath
        RestartDelaySeconds = $restartDelay
        RegisteredAt = (Get-Date).ToString("s")
    }
    $manifest | ConvertTo-Json -Depth 8 | Out-File -FilePath $manifestPath -Encoding UTF8

    $watchdog = "$Root\scripts\Run-DesktopServerApp-Watchdog.ps1"
    $taskName = "Desktop App - $safeName"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$watchdog`" -ManifestPath `"$manifestPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -TaskPath "\HomeServer\DesktopApps\" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

    Write-Host "Approved and registered: $appName" -ForegroundColor Green
    Write-Host "Manifest: $manifestPath"
    Write-Host "Task: HomeServer\DesktopApps\$taskName"
    Write-Host "Data: $dataPath"
    Write-Host "Secrets: $secretsPath"
}

function Register-DesktopServerAppsWizard {
    Create-DesktopServerAppsFolder
    Create-DesktopAppsScanScript
    Register-DesktopAppsScanTask
    $desktopFolder = Get-DesktopServerAppsFolder
    $dirs = @(Get-ChildItem -Path $desktopFolder -Directory -ErrorAction SilentlyContinue | Where-Object { -not $_.Name.StartsWith("_") })
    if ($dirs.Count -lt 1) {
        Write-Host "No app folders found yet. Put each app inside its own folder here:" -ForegroundColor Yellow
        Write-Host $desktopFolder
        return
    }

    foreach ($dir in $dirs) {
        if (Confirm-Choice "Scan and approve app folder '$($dir.Name)'?" $true) {
            Register-DesktopServerAppFolder -AppFolder $dir.FullName
        }
    }
    & "$Root\scripts\Scan-DesktopServerApps.ps1" -Root $Root
}

function Start-ApprovedDesktopServerAppsNow {
    Create-DesktopAppWatchdogScript
    $manifestDir = "$Root\config\desktop-apps"
    if (-not (Test-Path $manifestDir)) { Write-Host "No approved Desktop Server Apps yet." -ForegroundColor Yellow; return }
    $manifests = @(Get-ChildItem -Path $manifestDir -Filter "*.json" -ErrorAction SilentlyContinue)
    foreach ($m in $manifests) {
        $manifest = Get-Content $m.FullName -Raw | ConvertFrom-Json
        if ($manifest.Enabled -eq $false) { continue }
        $already = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*Run-DesktopServerApp-Watchdog.ps1*" -and $_.CommandLine -like "*$($m.Name)*" })
        if ($already.Count -gt 0) {
            Write-Host "Already running watchdog for: $($manifest.Name)"
            continue
        }
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Root\scripts\Run-DesktopServerApp-Watchdog.ps1`" -ManifestPath `"$($m.FullName)`"" -WindowStyle Minimized
        Write-Host "Started watchdog for: $($manifest.Name)"
    }
}

function Open-DesktopServerAppsFolder {
    Create-DesktopServerAppsFolder
    Start-Process (Get-DesktopServerAppsFolder)
}

function Open-FirewallPortWizard {
    $name = Read-Host "Friendly rule name, e.g. My App 8080"
    $portText = Read-Host "TCP port to open, e.g. 8080"
    if (-not ($portText -as [int])) { Write-Host "That was not a valid port number." -ForegroundColor Red; return }
    $port = [int]$portText
    if ($port -lt 1 -or $port -gt 65535) { Write-Host "Port must be between 1 and 65535." -ForegroundColor Red; return }
    $profile = if (Confirm-Choice "Open only on Private network profile? Recommended." $true) { "Private" } else { "Any" }
    New-NetFirewallRule -DisplayName "HomeServer - $name" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port -Profile $profile | Out-Null
    Write-Host "Created inbound TCP firewall rule for port $port on profile $profile."
}

function Enable-RemoteDesktopSafe {
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.Caption -match "Home") {
        Write-Host "Remote Desktop host is not available on Windows Home editions. Use Chrome Remote Desktop, RustDesk, AnyDesk, or Tailscale web dashboards." -ForegroundColor Yellow
        return
    }
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
    try { Enable-NetFirewallRule -DisplayGroup "Remote Desktop" | Out-Null } catch {}
    Write-Host "Remote Desktop enabled. Do not expose RDP directly to the internet. Use VPN-style access."
}

function Install-CommonTools {
    if ($SkipToolInstall) { Write-Host "Skipping tool installation because -SkipToolInstall was supplied."; return }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) { Write-Host "winget was not found. Install App Installer from Microsoft Store, then rerun this option." -ForegroundColor Yellow; return }

    $tools = @(
        @{ Name = "Git"; Id = "Git.Git" },
        @{ Name = "7-Zip"; Id = "7zip.7zip" },
        @{ Name = "PowerShell 7"; Id = "Microsoft.PowerShell" },
        @{ Name = "Docker Desktop"; Id = "Docker.DockerDesktop" }
    )
    foreach ($tool in $tools) {
        if (Confirm-Choice "Install or update $($tool.Name)?" $true) {
            winget install --id $tool.Id -e --accept-package-agreements --accept-source-agreements
        }
    }
}

function Install-OptionalRemoteTools {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) { Write-Host "winget was not found. Install App Installer from Microsoft Store first." -ForegroundColor Yellow; return }
    if (Confirm-Choice "Install Tailscale? Recommended for safe remote access." $true) {
        winget install --id Tailscale.Tailscale -e --accept-package-agreements --accept-source-agreements
        Write-Host "Tailscale installed. Open it and sign in, or run: tailscale up"
    }
}

function Install-WSLBase {
    if (Confirm-Choice "Install/enable WSL base components? This may require a reboot." $true) {
        try { wsl --install --no-distribution } catch { Write-Host "WSL install command failed or WSL may already be installed." -ForegroundColor Yellow }
    }
}

function Configure-HealthAlertsWizard {
    $cfg = Get-HomeServerConfig
    Write-Host "Alert providers: none, discord, telegram, ntfy, gotify, smtp"
    $provider = Read-Default "Provider" $cfg.AlertProvider
    $cfg.AlertProvider = $provider.ToLowerInvariant()
    switch ($cfg.AlertProvider) {
        "discord" { $cfg.DiscordWebhookUrl = Read-Default "Discord webhook URL" $cfg.DiscordWebhookUrl }
        "telegram" {
            $cfg.TelegramBotToken = Read-Default "Telegram bot token" $cfg.TelegramBotToken
            $cfg.TelegramChatId = Read-Default "Telegram chat ID" $cfg.TelegramChatId
        }
        "ntfy" { $cfg.NtfyTopic = Read-Default "ntfy.sh topic" $cfg.NtfyTopic }
        "gotify" {
            $cfg.GotifyUrl = Read-Default "Gotify URL, e.g. https://gotify.example.com" $cfg.GotifyUrl
            $cfg.GotifyToken = Read-Default "Gotify app token" $cfg.GotifyToken
        }
        "smtp" {
            $cfg.SmtpServer = Read-Default "SMTP server" $cfg.SmtpServer
            $cfg.SmtpPort = [int](Read-Default "SMTP port" ([string]$cfg.SmtpPort))
            $cfg.SmtpFrom = Read-Default "From address" $cfg.SmtpFrom
            $cfg.SmtpTo = Read-Default "To address" $cfg.SmtpTo
        }
        default { $cfg.AlertProvider = "none" }
    }
    Save-HomeServerConfig $cfg
    Write-Host "Alert configuration saved. The next health check will use it."
}

function Test-HealthAlert {
    $cfg = Get-HomeServerConfig
    if ($cfg.AlertProvider -eq "none") { Write-Host "Alert provider is set to none." -ForegroundColor Yellow; return }
    $script = "$Root\scripts\Health-Check.ps1"
    if (-not (Test-Path $script)) { Create-MaintenanceScripts }
    Write-Host "A test alert will be sent by temporarily adding a test issue to alert.log if configured."
    # Reuse provider logic through a tiny temporary sender to avoid duplicating too much here.
    $tmp = Join-Path $env:TEMP "homeserver-test-alert.ps1"
    $tmpSender = @"
`$config = Get-Content '$Script:ConfigPath' -Raw | ConvertFrom-Json
switch (`$config.AlertProvider) {
 'discord' { if (`$config.DiscordWebhookUrl) { Invoke-RestMethod -Method Post -Uri `$config.DiscordWebhookUrl -ContentType 'application/json' -Body (@{ content = '**HomeServer test alert**`nThis is a test from $env:COMPUTERNAME.' } | ConvertTo-Json) | Out-Null } }
 'telegram' { if (`$config.TelegramBotToken -and `$config.TelegramChatId) { Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot`$(`$config.TelegramBotToken)/sendMessage" -Body @{ chat_id = `$config.TelegramChatId; text = 'HomeServer test alert from $env:COMPUTERNAME' } | Out-Null } }
 'ntfy' { if (`$config.NtfyTopic) { Invoke-RestMethod -Method Post -Uri "https://ntfy.sh/`$(`$config.NtfyTopic)" -Body 'HomeServer test alert from $env:COMPUTERNAME' | Out-Null } }
 'gotify' { if (`$config.GotifyUrl -and `$config.GotifyToken) { `$uri = `$config.GotifyUrl.TrimEnd('/') + "/message?token=`$(`$config.GotifyToken)"; Invoke-RestMethod -Method Post -Uri `$uri -Body @{ title = 'HomeServer test alert'; message = 'Test from $env:COMPUTERNAME'; priority = 5 } | Out-Null } }
 default { Write-Host 'Test sender does not support this provider here. Health check will still use it.' }
}
"@
    $tmpSender | Out-File $tmp -Encoding UTF8
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmp
    Write-Host "Test alert attempted."
}

function Run-SecurityHardeningMenu {
    while ($true) {
        Write-Host ""
        Write-Host "Security hardening options" -ForegroundColor Cyan
        Write-Host "1. Disable SMBv1"
        Write-Host "2. Defender baseline: enable real-time protection and update signatures"
        Write-Host "3. Enable Controlled Folder Access for HomeServer folders"
        Write-Host "4. Set firewall default inbound to Block and export rules"
        Write-Host "5. Create a standard non-admin local user"
        Write-Host "6. Audit open inbound firewall rules"
        Write-Host "0. Back"
        $c = Read-Host "Selection"
        switch ($c) {
            "1" {
                Invoke-Step "Disable SMBv1" {
                    try { Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart | Out-Null } catch {}
                    try { Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force | Out-Null } catch {}
                    Write-Host "SMBv1 disable attempted. A reboot may be required."
                }
            }
            "2" {
                Invoke-Step "Defender baseline" {
                    try { Set-MpPreference -DisableRealtimeMonitoring $false } catch {}
                    try { Update-MpSignature } catch {}
                    Write-Host "Defender baseline applied where supported."
                }
            }
            "3" {
                Invoke-Step "Enable Controlled Folder Access" {
                    Write-Host "Controlled Folder Access can block some apps until you allow them." -ForegroundColor Yellow
                    if (Confirm-Choice "Enable it for extra ransomware protection?" $false) {
                        Set-MpPreference -EnableControlledFolderAccess Enabled
                        Add-MpPreference -ControlledFolderAccessProtectedFolders $Root
                        Write-Host "Controlled Folder Access enabled and HomeServer root added."
                    }
                }
            }
            "4" { Invoke-Step "Firewall default inbound block" { Configure-FirewallDefaultInboundBlock } }
            "5" {
                Invoke-Step "Create standard local user" {
                    $name = Read-Host "New local username, e.g. homeserveruser"
                    if ([string]::IsNullOrWhiteSpace($name)) { throw "Username required." }
                    $pw = Read-Host "Password" -AsSecureString
                    New-LocalUser -Name $name -Password $pw -FullName "Home Server Standard User" -Description "Standard account created by HomeServer wizard"
                    Add-LocalGroupMember -Group "Users" -Member $name
                    Write-Host "Created standard local user: $name"
                }
            }
            "6" {
                Invoke-Step "Audit firewall rules" {
                    $csv = "$Root\reports\open-inbound-firewall-rules.csv"
                    Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow |
                        Get-NetFirewallPortFilter |
                        Select-Object InstanceID, Protocol, LocalPort, RemotePort |
                        Export-Csv -NoTypeInformation -Path $csv
                    Write-Host "Firewall audit written to: $csv"
                }
            }
            "0" { return }
            default { Write-Host "Unknown selection." -ForegroundColor DarkYellow }
        }
    }
}

function Generate-SystemReport {
    $script = "$Root\scripts\Health-Check.ps1"
    if (-not (Test-Path $script)) { Create-MaintenanceScripts }
    & $script -Root $Root
    Write-Host "Report generated at: $Root\logs\health-report.txt"
    Get-Content "$Root\logs\health-report.txt" -ErrorAction SilentlyContinue | Select-Object -First 100
}

function Open-Dashboard {
    $dash = "$Root\dashboard\index.html"
    if (-not (Test-Path $dash)) { Create-DashboardFiles }
    Generate-SystemReport | Out-Null
    Start-Process $dash
    Write-Host "Dashboard opened: $dash"
    $Script:LastNotice = "Dashboard opened"
}

function Run-RecommendedSetup {
    Invoke-Step "Create HomeServer folder layout" { Create-FolderLayout }
    Invoke-Step "Create Desktop Server Apps drop-zone" { Create-DesktopServerAppsFolder }
    Invoke-Step "Configure always-on power settings" { Configure-PowerForServer }
    Invoke-Step "Configure deep power optimization" { Configure-DeepPowerOptimization }
    Invoke-Step "Enable Windows Firewall baseline" { Configure-FirewallBaseline }

    if (Confirm-Choice "Set current non-domain network profile to Private? Recommended for a home LAN." $true) {
        Invoke-Step "Configure network as Private" { Configure-PrivateNetworkProfile }
    }

    Invoke-Step "Set Windows Update active hours" { Configure-WindowsUpdateActiveHours }
    Invoke-Step "Create maintenance, backup, restore, dashboard, health, and Docker autostart scripts" { Create-MaintenanceScripts }
    Invoke-Step "Register backup and health-check scheduled tasks" { Register-MaintenanceTasks }
    Invoke-Step "Register Docker Compose autostart task" { Register-DockerAutostartTask }
    Invoke-Step "Create Desktop Server Apps scanner and watchdog" { Create-DesktopAppWatchdogScript; Create-DesktopAppsScanScript; Register-DesktopAppsScanTask }
    Invoke-Step "Create Docker Compose templates" { Create-DockerTemplates }
    Invoke-Step "Create reverse proxy templates" { Create-ReverseProxyTemplates }
    Invoke-Step "Create Cloudflare Tunnel template" { Create-CloudflareTunnelTemplate }
    Invoke-Step "Create Uptime Kuma compose file" { Create-UptimeKumaCompose }
    Invoke-Step "Generate router/BIOS checklist" { Generate-RouterBiosChecklist }

    if (-not $SkipToolInstall) {
        if (Confirm-Choice "Install common tools with winget? Git, 7-Zip, PowerShell 7, Docker Desktop." $false) {
            Invoke-Step "Install common tools" { Install-CommonTools }
            Invoke-Step "Install WSL base components" { Install-WSLBase }
        }
        if (Confirm-Choice "Install Tailscale for safer remote access?" $false) {
            Invoke-Step "Install optional remote tools" { Install-OptionalRemoteTools }
        }
    }

    if (Confirm-Choice "Deploy Uptime Kuma now if Docker is already installed/running?" $false) {
        Invoke-Step "Deploy Uptime Kuma" { Deploy-UptimeKuma }
    }

    if (Confirm-Choice "Enable Remote Desktop if your Windows edition supports it?" $false) {
        Invoke-Step "Enable Remote Desktop" { Enable-RemoteDesktopSafe }
    }

    Invoke-Step "Generate system report and dashboard status" { Generate-SystemReport }

    Write-Host ""
    Write-Host "Recommended HomeForge v4 setup complete." -ForegroundColor Green
    Write-Host "Important manual tasks still recommended:" -ForegroundColor Yellow
    Write-Host "1. Router: create a DHCP reservation using $Root\reports\Router-BIOS-Checklist.txt"
    Write-Host "2. BIOS/UEFI: enable power-on after AC loss."
    Write-Host "3. Log in to Tailscale/Cloudflare if you choose those tools."
    Write-Host "4. Add your real apps under $Root\apps."
    Write-Host "5. Open dashboard: $Root\dashboard\index.html"
}


function Normalize-AppEndpoint([string]$Endpoint) {
    if ([string]::IsNullOrWhiteSpace($Endpoint)) { return "" }
    $ep = $Endpoint.Trim()
    if (-not $ep.StartsWith('/')) { $ep = '/' + $ep }
    return $ep
}

function Join-AppUrl([string]$BaseUrl, [string]$Endpoint) {
    $base = $BaseUrl.TrimEnd('/')
    $ep = Normalize-AppEndpoint $Endpoint
    if ([string]::IsNullOrWhiteSpace($ep)) { return $base }
    return $base + $ep
}

function Get-AppEndpointRows([string]$BaseUrl, [string]$LocalBaseUrl, [string[]]$Endpoints) {
    $rows = @()
    foreach ($epRaw in $Endpoints) {
        $ep = Normalize-AppEndpoint $epRaw
        if ([string]::IsNullOrWhiteSpace($ep)) { continue }
        $name = $ep.Trim('/').Replace('/','_')
        if ([string]::IsNullOrWhiteSpace($name)) { $name = 'root' }
        $rows += [pscustomobject]@{
            Name = $name
            Path = $ep
            PublicUrl = Join-AppUrl $BaseUrl $ep
            LocalUrl = Join-AppUrl $LocalBaseUrl $ep
        }
    }
    return @($rows)
}

function Get-TailscaleFunnelDnsName {
    $cmd = Get-Command tailscale -ErrorAction SilentlyContinue
    if (-not $cmd) { return "" }
    try {
        $raw = & $cmd.Source status --json 2>$null | Out-String
        if ([string]::IsNullOrWhiteSpace($raw)) { return "" }
        $json = $raw | ConvertFrom-Json
        if ($json.Self -and $json.Self.DNSName) {
            return ([string]$json.Self.DNSName).TrimEnd('.')
        }
    } catch {}
    return ""
}

function Test-AppHttpUrlBrief([string]$Url) {
    try {
        $response = Invoke-WebRequest -Uri $Url -Method GET -UseBasicParsing -TimeoutSec 8
        return "PASS - HTTP $($response.StatusCode)"
    } catch {
        return "CHECK - $($_.Exception.Message)"
    }
}

function Write-AppConnectionConsoleSummary([object]$Info, [object[]]$EndpointRows) {
    Write-Title
    $width = Get-UIWidth
    Write-Host ("APP CONNECTION SETUP".PadLeft([Math]::Floor($width/2)+10,' ')) -ForegroundColor Yellow
    Write-HFBorder -Position top -Width $width
    Write-HFRow (' {0,-24} {1,-55} {2,-8}' -f 'Parameter','Value','Status') -Width $width -Color Gray
    Write-HFBorder -Position mid -Width $width
    $items = @(
        @{P='App Name'; V=$Info.AppName; S='OK'},
        @{P='Server URL'; V=$Info.ServerUrl; S='COPY'},
        @{P='Local Test URL'; V=$Info.LocalTestingUrl; S='COPY'},
        @{P='Health Check'; V=$Info.HealthCheckUrl; S='COPY'},
        @{P='Public Method'; V=$Info.PublicAccessMethod; S='INFO'},
        @{P='HTTPS'; V=$Info.HttpsStatus; S=$Info.HttpsStatusLabel},
        @{P='Router Forwarding'; V=$Info.RouterForwarding; S=$Info.RouterStatusLabel},
        @{P='Fixed Local IP'; V=$Info.FixedLocalIp; S='CHECK'},
        @{P='Output Folder'; V=$Info.OutputFolder; S='OK'}
    )
    foreach ($i in $items) {
        $color = switch ($i.S) { 'OK' {'Green'} 'COPY' {'Yellow'} 'PASS' {'Green'} 'CHECK' {'Red'} default {'Gray'} }
        Write-HFRow (' {0,-24} {1,-55} {2,-8}' -f $i.P, $i.V, $i.S) -Width $width -Color $color
    }
    Write-HFBorder -Position bottom -Width $width
    Write-Host ""
    Write-Host "COPY THIS INTO YOUR APP:" -ForegroundColor Yellow
    Write-Host "Server URL: $($Info.ServerUrl)" -ForegroundColor Green
    Write-Host "Health Check: $($Info.HealthCheckUrl)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Generated endpoints:" -ForegroundColor Yellow
    foreach ($row in $EndpointRows) { Write-Host ("  {0,-24} {1}" -f $row.Path, $row.PublicUrl) -ForegroundColor Gray }
    Write-Host ""
    Write-Host "Saved to: $($Info.OutputFolder)" -ForegroundColor Cyan
}

function Add-AppConnectionRegistryEntry([object]$Entry) {
    $registryPath = Join-Path $Root "app-connections\App-Connection-Registry.json"
    New-Item -ItemType Directory -Path (Split-Path $registryPath -Parent) -Force | Out-Null
    $items = @()
    if (Test-Path $registryPath) {
        try { $items = @(Get-Content $registryPath -Raw | ConvertFrom-Json) } catch { $items = @() }
    }
    $items += $Entry
    $items | ConvertTo-Json -Depth 10 | Out-File -FilePath $registryPath -Encoding UTF8
}

function New-AppConnectionSetupWizard {
    Create-FolderLayout
    Write-Title
    Write-Host "Generic App Connection Setup" -ForegroundColor Yellow
    Write-Host "This creates a new copy-ready folder for any app that needs to connect to this home server." -ForegroundColor Gray
    Write-Host ""

    $appName = Read-Default "App name" "My App"
    $safeName = Get-SafeName $appName
    $localPort = [int](Read-Default "Local API/backend port" "5088")
    $healthPath = Normalize-AppEndpoint (Read-Default "Health check path" "/api/health")
    $endpointDefault = "/api/health,/api/auth/login,/api/version,/api/bots,/api/kraken"
    $endpointText = Read-Default "Endpoint paths to generate, comma-separated" $endpointDefault
    $endpoints = @($endpointText -split ',' | ForEach-Object { Normalize-AppEndpoint $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($endpoints -notcontains $healthPath) { $endpoints = @($healthPath) + $endpoints }

    $network = Get-PrimaryNetworkInfo
    $localIp = if ($network -and $network.IPAddress) { $network.IPAddress } else { "127.0.0.1" }
    $mac = if ($network -and $network.MacAddress) { $network.MacAddress } else { "Unknown" }
    $gateway = if ($network -and $network.Gateway) { $network.Gateway } else { "Unknown" }
    $suggestedIp = if ($network) { Get-SuggestedReservedIP -IP $localIp -Gateway $gateway } else { $localIp }
    $localBaseUrl = "http://$localIp`:$localPort"
    $localhostBaseUrl = "http://localhost`:$localPort"

    Write-Host ""
    Write-Host "How should this app be reachable?" -ForegroundColor Cyan
    Write-Host "1. Local testing only, e.g. http://$localIp`:$localPort"
    Write-Host "2. I already have a domain or DDNS name"
    Write-Host "3. I do NOT have a domain - use Tailscale Funnel public HTTPS"
    Write-Host "4. I do NOT have a domain - create DuckDNS/DDNS setup pack"
    $mode = Read-Default "Choose 1, 2, 3, or 4" "3"

    $serverUrl = $localBaseUrl
    $productionPort = $localPort
    $publicMethod = "Local testing only"
    $httpsStatus = "Not required for local-only testing"
    $httpsLabel = "INFO"
    $routerForwarding = "Not required for local-only testing"
    $routerLabel = "OK"
    $publicHost = ""
    $tailscaleCommand = ""
    $publicPort = 443

    switch ($mode) {
        "2" {
            $hostName = Read-Default "Domain/DDNS host without https://" "$safeName.example.com"
            $hostName = $hostName.Trim().Replace('https://','').Replace('http://','').TrimEnd('/')
            $serverUrl = "https://$hostName"
            $productionPort = 443
            $publicHost = $hostName
            $publicMethod = "User-provided domain/DDNS over HTTPS"
            $httpsStatus = "Required: certificate must be valid for $hostName"
            $httpsLabel = "CHECK"
            $routerForwarding = "Required unless using a tunnel: external 443 -> $localIp`:$localPort or reverse proxy"
            $routerLabel = "CHECK"
        }
        "3" {
            $detectedTs = Get-TailscaleFunnelDnsName
            if ([string]::IsNullOrWhiteSpace($detectedTs)) { $detectedTs = "YOUR-DEVICE.YOUR-TLNET.ts.net" }
            $tsName = Read-Default "Tailscale Funnel DNS name" $detectedTs
            $portChoice = [int](Read-Default "Public HTTPS port for Funnel: 443, 8443, or 10000" "443")
            if (@(443,8443,10000) -notcontains $portChoice) {
                Write-Host "Tailscale Funnel only allows 443, 8443, or 10000. Using 443." -ForegroundColor Yellow
                $portChoice = 443
            }
            $publicPort = $portChoice
            $portSuffix = if ($publicPort -eq 443) { "" } else { ":$publicPort" }
            $serverUrl = "https://$tsName$portSuffix"
            $productionPort = $publicPort
            $publicHost = $tsName
            $publicMethod = "Tailscale Funnel public HTTPS"
            $httpsStatus = "Handled by Tailscale Funnel for the ts.net URL after Funnel is enabled"
            $httpsLabel = "CHECK"
            $routerForwarding = "Not required with Tailscale Funnel"
            $routerLabel = "OK"
            $tailscaleCommand = "tailscale funnel --https=$publicPort http://localhost:$localPort"
        }
        "4" {
            $sub = Read-Default "DuckDNS subdomain, without .duckdns.org" "$safeName-server"
            $sub = $sub.Trim().Replace('.duckdns.org','').Replace('https://','').Replace('http://','').TrimEnd('/')
            $hostName = "$sub.duckdns.org"
            $serverUrl = "https://$hostName"
            $productionPort = 443
            $publicHost = $hostName
            $publicMethod = "DuckDNS/DDNS plus HTTPS reverse proxy"
            $httpsStatus = "Required: use Caddy/reverse proxy/Let's Encrypt for $hostName"
            $httpsLabel = "CHECK"
            $routerForwarding = "Required: external 443 -> $localIp reverse proxy/API"
            $routerLabel = "CHECK"
        }
        default {
            $serverUrl = $localBaseUrl
            $productionPort = $localPort
        }
    }

    $endpointRows = Get-AppEndpointRows -BaseUrl $serverUrl -LocalBaseUrl $localBaseUrl -Endpoints $endpoints
    $healthUrl = Join-AppUrl $serverUrl $healthPath
    $localHealthUrl = Join-AppUrl $localBaseUrl $healthPath

    $apiName = Read-Default "Optional API process/service/container name to check" "$safeName.Api"
    $workerName = Read-Default "Optional worker process/service/container name to check" "$safeName.Worker"
    $dbName = Read-Default "Optional database process/service/container name to check" "database"
    $dbPortText = Read-Default "Optional local database port to check, blank to skip" ""

    $localHealthTest = "Not tested"
    if (Confirm-Choice "Test the local health URL now? $localHealthUrl" $false) {
        $localHealthTest = Test-AppHttpUrlBrief $localHealthUrl
    }
    $publicHealthTest = "Not tested"
    if ($serverUrl -ne $localBaseUrl -and (Confirm-Choice "Test the public health URL now? $healthUrl" $false)) {
        $publicHealthTest = Test-AppHttpUrlBrief $healthUrl
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $outputFolder = Join-Path $Root "app-connections\$safeName-$timestamp"
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null

    $info = [ordered]@{
        AppName = $appName
        SafeName = $safeName
        GeneratedAt = (Get-Date).ToString("s")
        OutputFolder = $outputFolder
        ServerUrl = $serverUrl
        LocalTestingUrl = $localBaseUrl
        LocalhostTestingUrl = $localhostBaseUrl
        ProductionPort = $productionPort
        LocalPort = $localPort
        PublicHost = $publicHost
        PublicAccessMethod = $publicMethod
        HealthCheckPath = $healthPath
        HealthCheckUrl = $healthUrl
        LocalHealthCheckUrl = $localHealthUrl
        HttpsStatus = $httpsStatus
        HttpsStatusLabel = $httpsLabel
        RouterForwarding = $routerForwarding
        RouterStatusLabel = $routerLabel
        FixedLocalIp = "Current: $localIp | Suggested reservation: $suggestedIp | MAC: $mac"
        Gateway = $gateway
        ApiName = $apiName
        WorkerName = $workerName
        DatabaseName = $dbName
        DatabasePort = $dbPortText
        LocalHealthTest = $localHealthTest
        PublicHealthTest = $publicHealthTest
        TailscaleCommand = $tailscaleCommand
    }

    $endpointTextOut = ($endpointRows | ForEach-Object { "  $($_.Path) -> $($_.PublicUrl)" }) -join "`r`n"
    $localEndpointTextOut = ($endpointRows | ForEach-Object { "  $($_.Path) -> $($_.LocalUrl)" }) -join "`r`n"

    $copyText = @"
APP CONNECTION INFO
Created by HomeForge v$Script:Version
Generated: $(Get-Date)

COPY THIS INTO YOUR APP

Server URL:
$serverUrl

Health Check URL:
$healthUrl

Local Testing URL:
$localBaseUrl

Localhost Testing URL:
$localhostBaseUrl

Port:
$productionPort

PUBLIC ACCESS METHOD
$publicMethod

HTTPS STATUS
$httpsStatus

ROUTER / INTERNET ACCESS
$routerForwarding

LOCAL NETWORK DETLS
Current local IP: $localIp
Suggested router DHCP reservation: $suggestedIp
Server MAC address: $mac
Router/gateway: $gateway

GENERATED PUBLIC ENDPOINTS
$endpointTextOut

GENERATED LOCAL ENDPOINTS
$localEndpointTextOut

APP-SIDE USAGE
Enter this as the server URL inside your app:
$serverUrl

The app can then call:
$healthPath

SAFETY RULES
- Expose only the public API/backend endpoint.
- Do not expose the database directly.
- Do not expose the worker directly.
- Do not expose logs, backups, secrets, or admin tools publicly.
- For real users outside your home, use HTTPS.
- For local-only testing, use the local testing URL.

CHECKS
Local health test: $localHealthTest
Public health test: $publicHealthTest
API name to check: $apiName
Worker name to check: $workerName
Database name to check: $dbName
Database port to check: $dbPortText
"@
    Write-TextFile (Join-Path $outputFolder "COPY-THIS-INTO-YOUR-APP.txt") $copyText

    $infoObject = [pscustomobject]$info
    $jsonOut = [ordered]@{
        app = $infoObject
        endpoints = $endpointRows
    }
    $jsonOut | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $outputFolder "app-connection-info.json") -Encoding UTF8
    Write-TextFile (Join-Path $outputFolder "server-url.txt") $serverUrl
    Write-TextFile (Join-Path $outputFolder "health-check-url.txt") $healthUrl

    $checkScript = @"
# App connection test script created by HomeForge.
# Run from PowerShell:
# powershell.exe -ExecutionPolicy Bypass -File .\Test-App-Connection.ps1

`$ErrorActionPreference = 'Continue'
`$ServerUrl = '$serverUrl'
`$LocalUrl = '$localBaseUrl'
`$HealthUrl = '$healthUrl'
`$LocalHealthUrl = '$localHealthUrl'
`$LocalPort = $localPort
`$ApiName = '$apiName'
`$WorkerName = '$workerName'
`$DatabaseName = '$dbName'
`$DatabasePort = '$dbPortText'

function Test-Url(`$name, `$url) {
    Write-Host "Testing `${name}: `$url" -ForegroundColor Cyan
    try {
        `$r = Invoke-WebRequest -Uri `$url -UseBasicParsing -TimeoutSec 10
        Write-Host "PASS HTTP `$(`$r.StatusCode)" -ForegroundColor Green
    } catch { Write-Host "CHECK `$(`$_.Exception.Message)" -ForegroundColor Yellow }
}

Write-Host "APP CONNECTION TEST" -ForegroundColor Yellow
Test-NetConnection -ComputerName localhost -Port `$LocalPort | Format-List ComputerName,RemotePort,TcpTestSucceeded
Test-Url 'local health' `$LocalHealthUrl
Test-Url 'public health' `$HealthUrl

foreach (`$name in @(`$ApiName, `$WorkerName, `$DatabaseName)) {
    if (-not [string]::IsNullOrWhiteSpace(`$name)) {
        `$proc = @(Get-Process -Name `$name -ErrorAction SilentlyContinue)
        `$svc = @(Get-Service -Name `$name -ErrorAction SilentlyContinue)
        Write-Host "Name check: `$name | Processes: `$(`$proc.Count) | Services: `$(`$svc.Count)" -ForegroundColor Gray
    }
}

if (-not [string]::IsNullOrWhiteSpace(`$DatabasePort)) {
    Test-NetConnection -ComputerName localhost -Port ([int]`$DatabasePort) | Format-List ComputerName,RemotePort,TcpTestSucceeded
}

try {
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
} catch { Write-Host "Docker not available or not running." -ForegroundColor DarkYellow }
"@
    Write-TextFile (Join-Path $outputFolder "Test-App-Connection.ps1") $checkScript

    $firewallScript = @"
# Opens local Windows Firewall ports for this app on Private networks.
# Only run if this app needs to be reachable on your LAN or through a reverse proxy.
New-NetFirewallRule -DisplayName "HomeForge - $appName local API $localPort" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $localPort -Profile Private -ErrorAction SilentlyContinue
# For direct HTTPS/reverse-proxy use, uncomment the next line:
# New-NetFirewallRule -DisplayName "HomeForge - HTTPS 443 for $appName" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 443 -Profile Private -ErrorAction SilentlyContinue
Write-Host "Firewall helper complete."
"@
    Write-TextFile (Join-Path $outputFolder "Open-Firewall-For-This-App.ps1") $firewallScript

    $caddyHost = if ([string]::IsNullOrWhiteSpace($publicHost)) { "your-domain.example.com" } else { $publicHost }
    $caddySnippet = @"
# Caddy reverse proxy snippet for $appName
# Save inside a Caddyfile if you use a domain/DDNS setup.
# This exposes ONLY the API/backend, not the database, worker, logs, backups, or secrets.

$caddyHost {
    reverse_proxy localhost:$localPort
}
"@
    Write-TextFile (Join-Path $outputFolder "Caddyfile-snippet.txt") $caddySnippet

    $checklist = @"
APP CONNECTION CHECKLIST

[ ] $appName backend/API is running on local port $localPort
[ ] Health check works locally: $localHealthUrl
[ ] Server URL copied into app: $serverUrl
[ ] Public health check works: $healthUrl
[ ] HTTPS is valid and trusted for real users
[ ] The server has a fixed local IP / router DHCP reservation
[ ] Only the API/backend is public
[ ] Worker is private
[ ] Database is private
[ ] Logs/backups/secrets/admin tools are private
[ ] Backups are configured in HomeForge
[ ] Health checks are configured in HomeForge

Router notes:
$routerForwarding

Suggested router DHCP reservation:
MAC: $mac
IP: $suggestedIp
"@
    Write-TextFile (Join-Path $outputFolder "Setup-Checklist.txt") $checklist

    if ($mode -eq "3") {
        $tailscaleScript = @"
# Start Tailscale Funnel for $appName.
# Requirements:
# 1. Tailscale is installed and logged in.
# 2. Funnel is enabled in your Tailscale admin settings.
# 3. $appName is running locally on http://localhost:$localPort

$tailscaleCommand

Write-Host "If Funnel started successfully, use this Server URL in your app: $serverUrl"
"@
        Write-TextFile (Join-Path $outputFolder "Start-Tailscale-Funnel.ps1") $tailscaleScript
        $tailscaleBat = @"
@echo off
cd /d "%~dp0"
title HomeForge - Start Tailscale Funnel for $appName
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Tailscale-Funnel.ps1"
pause
"@
        Write-TextFile (Join-Path $outputFolder "Start-Tailscale-Funnel.bat") $tailscaleBat
    }

    if ($mode -eq "4") {
        $duckScript = @"
# DuckDNS update template for $appName.
# 1. Create an account/subdomain at duckdns.org.
# 2. Replace PASTE_DUCKDNS_TOKEN_HERE with your DuckDNS token.
# 3. Run this script or schedule it every 5 minutes.

`$SubDomain = '$($publicHost.Replace('.duckdns.org',''))'
`$Token = 'PASTE_DUCKDNS_TOKEN_HERE'
`$Url = "https://www.duckdns.org/update?domains=`$SubDomain&token=`$Token&ip="
Invoke-RestMethod -Uri `$Url
Write-Host "DuckDNS update attempted for `$SubDomain.duckdns.org"
"@
        Write-TextFile (Join-Path $outputFolder "DuckDNS-Update-Template.ps1") $duckScript
    }

    $readme = @"
# $appName app connection folder

Created by HomeForge v$Script:Version.

Start with:

1. Open COPY-THIS-INTO-YOUR-APP.txt
2. Copy the Server URL into your desktop/mobile app
3. Run Test-App-Connection.ps1 to test local/public connectivity
4. Follow Setup-Checklist.txt

Most important value:

$serverUrl
"@
    Write-TextFile (Join-Path $outputFolder "README.txt") $readme

    Add-AppConnectionRegistryEntry ([pscustomobject]@{
        AppName = $appName
        GeneratedAt = $info.GeneratedAt
        ServerUrl = $serverUrl
        HealthCheckUrl = $healthUrl
        LocalTestingUrl = $localBaseUrl
        PublicAccessMethod = $publicMethod
        OutputFolder = $outputFolder
    })

    Write-AppConnectionConsoleSummary -Info $infoObject -EndpointRows $endpointRows
    if (Confirm-Choice "Open this app connection folder now?" $true) { Start-Process $outputFolder }
}

function Show-Menu {
    Write-Title
    $width = Get-UIWidth
    Write-Host ("MENU".PadLeft([Math]::Floor($width/2)+2,' ')) -ForegroundColor Yellow
    Write-HFBorder -Position top -Width $width
    Write-HFRow (' {0,-4} {1,-44} {2,-40}' -f 'No','Action','Description') -Width $width -Color Gray
    Write-HFBorder -Position mid -Width $width
    $items = @(
        @{ N='1';  A='Run recommended setup'; D='Best first run for most people' },
        @{ N='2';  A='Create/repair folders'; D='Build or fix the C:\HomeServer layout' },
        @{ N='3';  A='Always-on power tuning'; D='Disable sleep and optimise 24/7 power settings' },
        @{ N='4';  A='Windows Update hours'; D='Set a safer maintenance window' },
        @{ N='5';  A='Create server scripts'; D='Backup, restore, health, dashboard and helpers' },
        @{ N='6';  A='Register background tasks'; D='Backups, health checks and Docker auto-start' },
        @{ N='7';  A='Backup target setup'; D='Choose where backups are stored and kept' },
        @{ N='8';  A='Install common tools'; D='Git, 7-Zip, PowerShell 7, Docker Desktop' },
        @{ N='9';  A='Install remote-access tools'; D='Optional Tailscale install' },
        @{ N='10'; A='Deploy Uptime Kuma'; D='Start simple server monitoring' },
        @{ N='11'; A='Register a custom app'; D='Keep a chosen app running with recovery' },
        @{ N='12'; A='Open a firewall port'; D='Allow a selected app through the firewall' },
        @{ N='13'; A='Enable Remote Desktop'; D='Turn on RDP if Windows supports it' },
        @{ N='14'; A='Create app templates'; D='Docker, reverse proxy and Cloudflare templates' },
        @{ N='15'; A='Start Docker apps now'; D='Launch all compose apps under C:\HomeServer\apps' },
        @{ N='16'; A='Configure health alerts'; D='Discord, Telegram, ntfy, Gotify or email' },
        @{ N='17'; A='Security hardening'; D='Extra security tools and checks' },
        @{ N='18'; A='Router / BIOS checklist'; D='Create a personalised setup checklist' },
        @{ N='19'; A='Static IP setup'; D='Optional Windows static IP setup' },
        @{ N='20'; A='Generate health report'; D='Create and show the latest status report' },
        @{ N='21'; A='Open local dashboard'; D='Open the HomeForge dashboard in browser' },
        @{ N='22'; A='Encrypted backup'; D='Make a one-time encrypted backup' },
        @{ N='23'; A='Open Desktop app drop-zone'; D='Open the “Home Server Apps” Desktop folder' },
        @{ N='24'; A='Scan / register Desktop apps'; D='Approve launchers and add watchdogs' },
        @{ N='25'; A='Start approved Desktop apps'; D='Start all approved app watchdogs now' },
        @{ N='26'; A='Harden secrets folders'; D='Protect secrets with tighter permissions' },
        @{ N='27'; A='App connection setup'; D='Generate copy-ready URLs, IPs and endpoints' },
        @{ N='0';  A='Exit'; D='Close HomeForge' }
    )
    foreach ($item in $items) {
        $color = if ($item.N -eq '0') { 'DarkGray' } else { 'Green' }
        Write-HFRow (' {0,-4} {1,-44} {2,-40}' -f $item.N, $item.A, $item.D) -Width $width -Color $color
    }
    Write-HFBorder -Position bottom -Width $width
    Write-Host ""
}


Restart-AsAdminIfNeeded
Set-ConsoleTheme
Initialize-Logging
Initialize-Config

try {
    if ($Auto) {
        Run-RecommendedSetup
        return
    }

    while ($true) {
        Show-Menu
        $choice = Read-Host "Select action"
        switch ($choice) {
            "1" { Run-RecommendedSetup }
            "2" { Invoke-Step "Create HomeServer folder layout" { Create-FolderLayout } }
            "3" { Invoke-Step "Configure always-on and deep power settings" { Configure-DeepPowerOptimization } }
            "4" { Invoke-Step "Set Windows Update active hours" { Configure-WindowsUpdateActiveHours } }
            "5" { Invoke-Step "Create maintenance scripts" { Create-MaintenanceScripts } }
            "6" { Invoke-Step "Register maintenance tasks" { Register-MaintenanceTasks }; Invoke-Step "Register Docker autostart task" { Register-DockerAutostartTask } }
            "7" { Invoke-Step "Configure backup target" { Configure-BackupTargetWizard } }
            "8" { Invoke-Step "Install common tools" { Install-CommonTools }; Invoke-Step "Install WSL base components" { Install-WSLBase } }
            "9" { Invoke-Step "Install optional remote-access tools" { Install-OptionalRemoteTools } }
            "10" { Invoke-Step "Deploy Uptime Kuma" { Deploy-UptimeKuma } }
            "11" { Invoke-Step "Register custom startup app" { Register-CustomStartupApp } }
            "12" { Invoke-Step "Open firewall port" { Open-FirewallPortWizard } }
            "13" { Invoke-Step "Enable Remote Desktop" { Enable-RemoteDesktopSafe } }
            "14" { Invoke-Step "Create Docker templates" { Create-DockerTemplates }; Invoke-Step "Create reverse proxy templates" { Create-ReverseProxyTemplates }; Invoke-Step "Create Cloudflare Tunnel template" { Create-CloudflareTunnelTemplate } }
            "15" { Invoke-Step "Start all Docker Compose apps" { Start-AllDockerAppsNow } }
            "16" { Invoke-Step "Configure health alerts" { Configure-HealthAlertsWizard }; if (Confirm-Choice "Send test alert now?" $false) { Invoke-Step "Send test alert" { Test-HealthAlert } } }
            "17" { Run-SecurityHardeningMenu }
            "18" { Invoke-Step "Generate router/BIOS checklist" { Generate-RouterBiosChecklist } }
            "19" { Invoke-Step "Static IP setup" { Configure-StaticIPWizard } }
            "20" { Invoke-Step "Generate system report" { Generate-SystemReport } }
            "21" { Invoke-Step "Open dashboard" { Open-Dashboard } }
            "22" { Invoke-Step "Create one-time encrypted backup" { if (-not (Test-Path "$Root\scripts\Create-Encrypted-Backup.ps1")) { Create-MaintenanceScripts }; & "$Root\scripts\Create-Encrypted-Backup.ps1" -Root $Root } }
            "23" { Invoke-Step "Create/open Desktop Server Apps drop-zone" { Open-DesktopServerAppsFolder } }
            "24" { Invoke-Step "Scan/register Desktop Server Apps" { Register-DesktopServerAppsWizard } }
            "25" { Invoke-Step "Start approved Desktop Server Apps now" { Start-ApprovedDesktopServerAppsNow } }
            "26" { Invoke-Step "Harden secrets folder permissions" { Harden-SecretsFolder } }
            "27" { Invoke-Step "App connection setup" { New-AppConnectionSetupWizard } }
            "0" { break }
            default { Write-Host "Unknown selection." -ForegroundColor DarkYellow; $Script:LastNotice = "Unknown selection" }
        }
        if ($choice -ne "0") {
            Write-Host ""
            Read-Host "Press Enter to return to HomeForge"
        }
    }
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
    if ($Script:LogFile) { Write-Host "Setup log: $Script:LogFile" }
}
