$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExePath = Join-Path $Root 'publish\win-x64\HomeForge.exe'
$IconPath = Join-Path $Root 'publish\win-x64\HomeForge.ico'

if (-not (Test-Path $ExePath)) {
    Write-Host 'HomeForge.exe was not found in publish\win-x64.' -ForegroundColor Yellow
    Write-Host 'Run Build-HomeForge.bat first.' -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $IconPath)) {
    $ProjectIcon = Join-Path $Root 'src\HomeForge.App\Assets\HomeForge.ico'
    if (Test-Path $ProjectIcon) {
        Copy-Item $ProjectIcon $IconPath -Force
    }
}

$Desktop = [Environment]::GetFolderPath('Desktop')
$ShortcutPath = Join-Path $Desktop 'HomeForge.lnk'
$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $ExePath
$Shortcut.WorkingDirectory = Split-Path -Parent $ExePath
if (Test-Path $IconPath) {
    $Shortcut.IconLocation = $IconPath
}
$Shortcut.Description = 'HomeForge'
$Shortcut.Save()

Write-Host "Desktop shortcut created:" -ForegroundColor Green
Write-Host $ShortcutPath
