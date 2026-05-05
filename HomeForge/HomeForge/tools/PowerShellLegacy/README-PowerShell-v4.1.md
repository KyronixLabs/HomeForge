# HomeForge v4.1

HomeForge is a polished Windows terminal-based setup tool that turns a Windows 11 mini PC into a cleaner, always-on home server.

## New in v4.1

- Branded **HomeForge** console interface

- Generic **App Connection Setup** generator
- Creates one timestamped folder per app under `C:\HomeServerpp-connections`
- Generates copy-ready server URL, local testing URL, health URL, endpoint list, IP/MAC/router info, and setup checklist
- Supports local-only testing, existing domain/DDNS, Tailscale Funnel public HTTPS, and DuckDNS setup packs
- Generates helper files such as `Test-App-Connection.ps1`, `Start-Tailscale-Funnel.ps1`, `Caddyfile-snippet.txt`, and `Open-Firewall-For-This-App.ps1`
- Cleaner black-and-gold control panel look
- Status table at the top of the app
- Nicer menu layout with actions and descriptions
- Better beginner-friendly launchers:
  - `Run-HomeForge-AsAdmin.bat`
  - `Run-HomeForge-Recommended-Auto.bat`
- Legacy launcher files are still included too

## Run it

Right-click one of these and choose **Run as administrator**:

```text
Run-HomeForge-AsAdmin.bat
Run-HomeForge-Recommended-Auto.bat
```

## What it still does

- Creates the `C:\HomeServer` folder structure
- Tunes Windows for 24/7 operation
- Creates backup, restore, health-check, Docker autostart, and dashboard scripts
- Registers scheduled tasks
- Creates Docker and reverse proxy templates
- Creates a Desktop **Home Server Apps** drop-zone
- Scans and registers approved Desktop apps with watchdogs
- Creates logs, data folders, secrets folders, and a dashboard
- Helps with Tailscale, Uptime Kuma, firewall rules, and security hardening

## Best first run

1. Run `Run-HomeForge-AsAdmin.bat`
2. Choose `1. Run recommended setup`
3. Put portable apps inside `Desktop\Home Server Apps`
4. Choose `24. Scan / register Desktop apps`
5. Open the dashboard from option `21`


## App Connection Setup

Use menu option:

```text
27. App connection setup
```

Each run creates a new folder like:

```text
C:\HomeServerpp-connections\My-App-2026-05-05_12-30-00
```

That folder contains copy-ready connection details for that app, including:

```text
Server URL
Local Testing URL
Health Check URL
Generated endpoint URLs
Current local IP
Suggested fixed router IP
MAC address
HTTPS/public access notes
Router checklist
Test scripts
```

For users without a domain, choose the Tailscale Funnel option to generate a public HTTPS setup pack. For users with DuckDNS or another DDNS provider, choose the DDNS option.
