# HomeForge

HomeForge is a Windows desktop app for preparing a spare Windows PC or mini PC as a reliable home server.

It provides a clean interface for setting up server folders, app hosting, connection details, backups, monitoring, logs, security checks, and maintenance tools.

## Repository description

A Windows desktop app that helps turn a spare Windows PC or mini PC into a reliable home server for apps, backups, monitoring, remote access, and public connection setup.

## Features

## Dashboard

The dashboard shows the current server state in one place.

It displays:

1. Server name
2. Local IP address
3. Administrator status
4. Docker status
5. Tailscale status
6. Server folder status
7. App folder status
8. Basic system details

## Connections

The Connections page creates connection details for hosted apps.

For each app, HomeForge can create a separate connection folder with copy ready information.

Generated files can include:

1. Server URL
2. Local testing URL
3. Health check URL
4. API endpoint list
5. Connection information in JSON format
6. PowerShell connection test script
7. Setup checklist
8. Tailscale Funnel helper script
9. DuckDNS helper template
10. Firewall helper script

## Public access options

HomeForge supports different connection styles.

## Local testing

Local testing is used when an app only needs to work inside the home network.

Example:

```text
http://192.168.1.50:5088
```

## Tailscale Funnel

Tailscale Funnel can be used to create a public HTTPS address without managing a domain.

HomeForge can generate the connection details and helper scripts for this setup.

## Existing domain or DDNS

Existing domain or dynamic DNS setups can be used for apps that already have a public address.

HomeForge can generate the server URL, checklist, and helper files for that setup.

## Apps

The Apps page helps organise apps that need to run on the server.

HomeForge can create a Desktop folder where app folders can be placed.

Each app should have its own folder.

Example:

```text
Home Server Apps
  My Bot
    start.bat
    bot.exe

  My API
    server.exe
    config.json
```

HomeForge can scan app folders and register the correct launcher.

For each registered app, HomeForge can create folders for:

1. App data
2. App logs
3. App secrets

## Setup

The Setup page contains tools for preparing the PC as a server.

It includes sections for:

1. Essentials
2. Server setup
3. Installers

Available setup actions include:

1. Create the HomeForge folder structure
2. Apply always on power settings
3. Improve power reliability
4. Enable firewall protection
5. Set the network profile
6. Set Windows Update active hours
7. Create maintenance scripts
8. Register backup and health tasks
9. Create Docker helper files
10. Create a local dashboard
11. Generate router and BIOS notes
12. Create the app folder drop zone
13. Harden secrets folders

Administrator access is required for some setup actions.

## Backups

The Backups page provides access to backup and restore tools.

HomeForge can create backup scripts and folders for important server data.

Backup targets can include:

1. App data
2. App configuration
3. Connection files
4. Secrets folder
5. Scripts
6. Templates

## Security

The Security page contains tools and checks for safer server use.

HomeForge can help with:

1. Firewall checks
2. Secrets folder protection
3. Safer remote access setup
4. Router and BIOS checklist generation
5. Basic hardening tasks

HomeForge is designed to avoid exposing private server areas.

Private areas include:

1. Database ports
2. Worker apps
3. Backup folders
4. Log folders
5. Admin tools
6. Secret files

## Logs

The Logs page provides access to output from HomeForge actions.

Logs can be used for:

1. Reviewing completed actions
2. Checking generated files
3. Debugging setup problems
4. Confirming script output

## Recommended setup flow

1. Build and open HomeForge
2. Run HomeForge as administrator
3. Open the Setup page
4. Create the HomeForge folders
5. Apply always on power settings
6. Create backup and health tools
7. Add the first app
8. Generate connection details for the app
9. Test the app connection
10. Review logs and dashboard status

## Building the app

HomeForge can be built with Visual Studio or with the included build script.

## Build with Visual Studio

1. Open `HomeForge.sln`
2. Select the HomeForge app project
3. Build the solution
4. Run the app

## Build with the script

Run this file from the repository root:

```text
Build-HomeForge.bat
```

The build script publishes the app into the publish folder.

## Requirements

HomeForge is built for Windows.

Recommended environment:

1. Windows 11
2. Visual Studio 2022
3. .NET desktop development workload
4. .NET 8 or newer
5. Administrator access for full setup features

Optional tools:

1. Docker Desktop
2. Tailscale
3. Git
4. Seven Zip
5. PowerShell 7

Optional tools are detected by HomeForge when available.

## Folder layout

HomeForge uses this main folder by default:

```text
C:\HomeServer
```

The folder can contain:

1. Apps
2. Backups
3. Config
4. Dashboard
5. Data
6. Logs
7. Reports
8. Restore files
9. Scripts
10. Secrets
11. Templates

## App connection folders

Each app connection setup creates a separate folder.

The folder can contain:

1. Copy ready server URL
2. Health check URL
3. Endpoint list
4. Connection JSON
5. Test script
6. Setup checklist
7. Public access helper scripts

## Use cases

HomeForge is useful for:

1. Hosting a personal API
2. Running a private bot
3. Running a local dashboard
4. Hosting a small backend service
5. Running a worker app from home
6. Managing a mini PC as a home server
7. Preparing a Windows machine for always on app hosting
8. Creating connection details for desktop or mobile apps

## Limits

Some setup tasks require manual action outside the app.

Examples include:

1. BIOS settings
2. Router login
3. Domain purchase
4. Outside account setup
5. App secrets
6. App specific port decisions
7. Hardware and internet uptime

HomeForge provides files, folders, scripts, checks, and setup notes for these areas where possible.

## Safe hosting guidance

Only the required app service should be reachable from outside the network.

For most setups, public access should point only to the main API or web service.

HTTPS is recommended for real users.

Local IP addresses are intended for home network testing.

## Suggested access paths

## Local network

Use the local IP and app port.

Example:

```text
http://192.168.1.50:5088
```

## Public access without a domain

Use Tailscale Funnel.

## Public access with a domain

Use a domain or subdomain with HTTPS.

## Project structure

The project is split into clear parts.

1. App project for the WPF interface
2. Core project for shared helpers
3. Models project for shared data models
4. Services project for Windows and server setup logic

## Contributing

Contributions are welcome.

Useful areas to improve include:

1. More setup checks
2. Better app detection
3. More backup options
4. Cleaner dashboard cards
5. More connection providers
6. More guided setup flows
7. Better error messages
8. More tests

## License

See the repository license file.

## Project goal

HomeForge exists to make it easier to turn a spare Windows PC into a clean, reliable, always on home server.
