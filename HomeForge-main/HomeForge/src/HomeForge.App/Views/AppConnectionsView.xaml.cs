using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using HomeForge.Models;
using HomeForge.Services;

namespace HomeForge.App.Views;

public partial class AppConnectionsView : UserControl
{
    private readonly AppConnectionService _service;
    private AppConnectionProfile? _lastProfile;

    public AppConnectionsView(AppConnectionService service)
    {
        InitializeComponent();
        _service = service;
    }

    private void Generate_Click(object sender, RoutedEventArgs e)
    {
        if (!int.TryParse(LocalPortBox.Text.Trim(), out var localPort) || localPort < 1 || localPort > 65535)
        {
            MessageBox.Show("Enter a valid local port between 1 and 65535.", "HomeForge", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var method = PublicAccessMethod.TailscaleFunnel;
        if (MethodBox.SelectedItem is ComboBoxItem item && item.Tag is string tag && Enum.TryParse<PublicAccessMethod>(tag, out var parsed))
        {
            method = parsed;
        }

        _lastProfile = _service.Generate(AppNameBox.Text.Trim(), localPort, method, PublicHostBox.Text.Trim(), EndpointsBox.Text);
        ResultBox.Text = BuildDisplay(_lastProfile);
    }

    private static string BuildDisplay(AppConnectionProfile p)
    {
        var endpoints = string.Join(Environment.NewLine, p.Endpoints.Select(e => "  " + p.ServerUrl.TrimEnd('/') + e));
        return $"""
        CONNECTION PROFILE
        ==================

        App name:
        {p.AppName}

        Server URL:
        {p.ServerUrl}

        Health URL:
        {p.HealthUrl}

        Local URL:
        {p.LocalTestingUrl}

        Public access method:
        {p.AccessMethod}

        Local port:
        {p.LocalPort}

        Public port:
        {p.PublicPort}

        HTTPS expected:
        {p.HttpsExpected}

        Endpoint URLs:
        {endpoints}

        Profile folder:
        {p.FolderPath}
        """;
    }

    private void CopyServerUrl_Click(object sender, RoutedEventArgs e)
    {
        if (_lastProfile is null) return;
        Clipboard.SetText(_lastProfile.ServerUrl);
    }

    private void CopyAll_Click(object sender, RoutedEventArgs e)
    {
        if (!string.IsNullOrWhiteSpace(ResultBox.Text)) Clipboard.SetText(ResultBox.Text);
    }

    private void OpenFolder_Click(object sender, RoutedEventArgs e)
    {
        var folderPath = _lastProfile?.FolderPath;
        if (string.IsNullOrWhiteSpace(folderPath) || !Directory.Exists(folderPath)) return;
        Process.Start(new ProcessStartInfo(folderPath) { UseShellExecute = true });
    }
}
