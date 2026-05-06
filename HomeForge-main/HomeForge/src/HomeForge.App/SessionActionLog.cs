using System.Text;

namespace HomeForge.App;

public static class SessionActionLog
{
    private static readonly StringBuilder Buffer = new();

    public static bool HasEntries => Buffer.Length > 0;

    public static string Text => Buffer.ToString();

    public static bool IsProgressVisible { get; private set; }

    public static bool IsProgressIndeterminate { get; private set; }

    public static double ProgressValue { get; private set; }

    public static string ProgressText { get; private set; } = "Ready";

    public static void Append(string text)
    {
        if (Buffer.Length > 0)
        {
            Buffer.AppendLine();
            Buffer.AppendLine(new string('─', 72));
        }

        Buffer.AppendLine($"[{DateTime.Now:g}]");
        Buffer.AppendLine(text.TrimEnd());
    }

    public static void StartProgress(string text, bool indeterminate = false)
    {
        IsProgressVisible = true;
        IsProgressIndeterminate = indeterminate;
        ProgressValue = indeterminate ? 0 : 4;
        ProgressText = text;
    }

    public static void UpdateProgress(double value, string text)
    {
        IsProgressVisible = true;
        IsProgressIndeterminate = false;
        ProgressValue = Math.Clamp(value, 0, 100);
        ProgressText = text;
    }

    public static void CompleteProgress(string text)
    {
        IsProgressVisible = true;
        IsProgressIndeterminate = false;
        ProgressValue = 100;
        ProgressText = text;
    }

    public static void HideProgress()
    {
        IsProgressVisible = false;
        IsProgressIndeterminate = false;
        ProgressValue = 0;
        ProgressText = "Ready";
    }
}
