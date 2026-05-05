using System.Text.RegularExpressions;

namespace HomeForge.Core;

public static partial class SafeName
{
    public static string Make(string input, string fallback = "App")
    {
        if (string.IsNullOrWhiteSpace(input)) return fallback;
        var cleaned = InvalidCharsRegex().Replace(input.Trim(), "-");
        cleaned = MultiDashRegex().Replace(cleaned, "-").Trim('-', '.', ' ');
        return string.IsNullOrWhiteSpace(cleaned) ? fallback : cleaned;
    }

    [GeneratedRegex("[^a-zA-Z0-9._ -]")]
    private static partial Regex InvalidCharsRegex();

    [GeneratedRegex("[- ]{2,}")]
    private static partial Regex MultiDashRegex();
}
