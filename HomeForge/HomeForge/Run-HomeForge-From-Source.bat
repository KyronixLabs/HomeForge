@echo off
setlocal
cd /d "%~dp0"
title HomeForge Run From Source
color 0E

where dotnet >nul 2>nul
if errorlevel 1 (
    echo [ERROR] .NET SDK was not found. Install .NET 8 SDK first.
    pause
    exit /b 1
)

dotnet run --project src\HomeForge.App\HomeForge.App.csproj -c Release
pause
