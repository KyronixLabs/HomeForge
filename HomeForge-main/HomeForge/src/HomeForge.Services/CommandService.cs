using System.Diagnostics;
using System.Text;
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
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8
        };

        using var process = new Process { StartInfo = psi, EnableRaisingEvents = true };
        var standardOutput = new StringBuilder();
        var standardError = new StringBuilder();
        var outputComplete = new ManualResetEventSlim(false);
        var errorComplete = new ManualResetEventSlim(false);

        process.OutputDataReceived += (_, e) =>
        {
            if (e.Data is null)
            {
                outputComplete.Set();
                return;
            }

            standardOutput.AppendLine(e.Data);
        };

        process.ErrorDataReceived += (_, e) =>
        {
            if (e.Data is null)
            {
                errorComplete.Set();
                return;
            }

            standardError.AppendLine(e.Data);
        };

        if (!process.Start())
        {
            throw new InvalidOperationException($"Could not start {fileName}.");
        }

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        if (!process.WaitForExit(timeoutSeconds * 1000))
        {
            try { process.Kill(entireProcessTree: true); } catch { }
            return new CommandResult
            {
                ExitCode = -1,
                StandardOutput = standardOutput.ToString(),
                StandardError = $"Timed out after {timeoutSeconds} seconds.\r\n{standardError}"
            };
        }

        outputComplete.Wait(TimeSpan.FromSeconds(2));
        errorComplete.Wait(TimeSpan.FromSeconds(2));

        return new CommandResult
        {
            ExitCode = process.ExitCode,
            StandardOutput = standardOutput.ToString(),
            StandardError = standardError.ToString()
        };
    }

    public Task<CommandResult> RunAsync(string fileName, string arguments, int timeoutSeconds = 60, CancellationToken cancellationToken = default)
    {
        return Task.Run(() => Run(fileName, arguments, timeoutSeconds), cancellationToken);
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
