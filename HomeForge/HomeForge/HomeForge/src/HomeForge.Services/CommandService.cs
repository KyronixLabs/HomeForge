using System.Diagnostics;
using HomeForge.Models;

namespace HomeForge.Services;

public sealed class CommandService
{
    public bool CommandExists(string command)
    {
        try
        {
            var result = Run("where.exe", command, timeoutSeconds: 5);
            return result.Success && !string.IsNullOrWhiteSpace(result.StandardOutput);
        }
        catch
        {
            return false;
        }
    }

    public CommandResult RunPowerShell(string script, int timeoutSeconds = 60)
    {
        return Run("powershell.exe", $"-NoProfile -ExecutionPolicy Bypass -Command \"{script.Replace("\"", "`\"")}\"", timeoutSeconds);
    }

    public CommandResult Run(string fileName, string arguments, int timeoutSeconds = 60)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(psi) ?? throw new InvalidOperationException($"Could not start {fileName}.");
        if (!process.WaitForExit(timeoutSeconds * 1000))
        {
            try { process.Kill(entireProcessTree: true); } catch { }
            return new CommandResult { ExitCode = -1, StandardError = $"Timed out after {timeoutSeconds} seconds." };
        }

        return new CommandResult
        {
            ExitCode = process.ExitCode,
            StandardOutput = process.StandardOutput.ReadToEnd(),
            StandardError = process.StandardError.ReadToEnd()
        };
    }

    public void RunElevatedPowerShellFile(string scriptPath, string arguments = "")
    {
        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\" {arguments}",
            UseShellExecute = true,
            Verb = "runas"
        };
        Process.Start(psi);
    }
}
