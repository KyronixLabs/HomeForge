# HomeForge

HomeForge is a Windows desktop app for preparing a Windows 11 PC to run always-on home server applications.

The package includes a Visual Studio solution:

```text
HomeForge.sln
```

## Build requirements

- Windows 11
- .NET 8 SDK
- Windows Desktop workload

Open `HomeForge.sln` in Visual Studio and build/run `HomeForge.App`.

## Build without Visual Studio

Run:

```text
Build-HomeForge.bat
```

The published app will be created here:

```text
publish\win-x64\HomeForge.exe
```

Helper scripts:

```text
Run-HomeForge-From-Source.bat
Clean-HomeForge.bat
```

## Projects

```text
src/HomeForge.App       WPF desktop UI
src/HomeForge.Core      Shared paths and helpers
src/HomeForge.Models    Data models
src/HomeForge.Services  Windows/server automation services
```

## Main features

- Professional WPF interface with left-side navigation
- Dashboard with structured server-readiness cards
- Connection profile generator for any hosted app
- Local URL, public URL, health URL and endpoint generation
- Tailscale Funnel helper scripts
- DuckDNS helper template
- Hosted applications folder manager
- Server setup tools for folders, power settings, firewall, maintenance tasks and monitoring
- Backup, restore, reports and security pages
- Build scripts for command-line publishing

## Administrator access

Some setup actions change Windows settings. Run HomeForge as Administrator when using server preparation, firewall, scheduled task or power-management features.

## Advanced script tools

The original PowerShell automation script is included under:

```text
tools\PowerShellLegacy
```

The desktop app provides the main workflow. The script tools remain available for advanced troubleshooting and command-line use.

## Polish update

This build removes temporary wording, tightens the UI copy, replaces raw dashboard output with structured status cards, shortens navigation labels, improves setup grouping and keeps advanced output inside the action log and logs page.


## Source cleanup note

This package keeps the working HomeForge UI and feature set intact. The source cleanup is intentionally conservative: comments, documentation and helper wording were tidied without changing the application flow, method contracts or generated project structure.
