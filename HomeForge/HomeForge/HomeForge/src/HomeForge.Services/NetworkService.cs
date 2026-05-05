using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace HomeForge.Services;

public sealed class NetworkService
{
    public string GetBestLocalIPv4()
    {
        try
        {
            foreach (var networkInterface in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (networkInterface.OperationalStatus != OperationalStatus.Up) continue;
                if (networkInterface.NetworkInterfaceType is NetworkInterfaceType.Loopback or NetworkInterfaceType.Tunnel) continue;

                var props = networkInterface.GetIPProperties();
                if (props.GatewayAddresses.Count == 0) continue;

                foreach (var unicast in props.UnicastAddresses)
                {
                    if (unicast.Address.AddressFamily == AddressFamily.InterNetwork &&
                        !IPAddress.IsLoopback(unicast.Address))
                    {
                        return unicast.Address.ToString();
                    }
                }
            }
        }
        catch
        {
            // Keep UI resilient. The status page will show fallback.
        }

        return "127.0.0.1";
    }

    public string GetPrimaryMacAddress()
    {
        try
        {
            foreach (var networkInterface in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (networkInterface.OperationalStatus != OperationalStatus.Up) continue;
                if (networkInterface.NetworkInterfaceType is NetworkInterfaceType.Loopback or NetworkInterfaceType.Tunnel) continue;
                if (networkInterface.GetIPProperties().GatewayAddresses.Count == 0) continue;
                return string.Join("-", networkInterface.GetPhysicalAddress().GetAddressBytes().Select(b => b.ToString("X2")));
            }
        }
        catch
        {
            // ignored
        }
        return "Unavailable";
    }
}
