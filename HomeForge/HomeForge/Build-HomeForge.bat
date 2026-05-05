@echo off
setlocal
cd /d "%~dp0"
title HomeForge Build
color 0E

echo ============================================================
echo   H O M E F O R G E  
echo ============================================================
echo.

where dotnet >nul 2>nul
if errorlevel 1 (
    echo [ERROR] .NET SDK was not found.
    echo.
    echo Install the .NET 8 SDK first:
    echo https://dotnet.microsoft.com/download/dotnet/8.0
    echo.
    pause
    exit /b 1
)

echo [1/4] Checking .NET SDK...
dotnet --version
if errorlevel 1 goto :fail

echo.
echo [2/4] Restoring packages...
dotnet restore HomeForge.sln
if errorlevel 1 goto :fail

echo.
echo [3/4] Building Release solution...
dotnet build HomeForge.sln -c Release --no-restore
if errorlevel 1 goto :fail

echo.
echo [4/4] Publishing HomeForge.App...
if not exist publish mkdir publish
dotnet publish src\HomeForge.App\HomeForge.App.csproj -c Release -r win-x64 --self-contained false -o publish\win-x64
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo   BUILD COMPLETE
echo ============================================================
echo.
echo Published app folder:
echo %CD%\publish\win-x64
echo.
echo Run:
echo %CD%\publish\win-x64\HomeForge.exe
echo.
pause
exit /b 0

:fail
echo.
echo ============================================================
echo   BUILD FAILED
echo ============================================================
echo Review the error messages above.
echo.
pause
exit /b 1
