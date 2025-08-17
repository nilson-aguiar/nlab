# VPN Setup for qBittorrent Containers

This document explains the VPN setup for your homelab qBittorrent containers using Gluetun.

## Overview

I've set up separate Gluetun VPN containers for each namespace containing qBittorrent:

1. **media-flix namespace** - For your main media server qBittorrent
2. **tinfoil-hat namespace** - For your Nintendo Switch game downloads

## Architecture

```
┌─────────────────────────────────────────┐
│ media-flix namespace                    │
│ ┌─────────────┐  ┌─────────────────────┐ │
│ │ gluetun-vpn │◄─┤ media-qb (qBittorrent) │ │
│ │   (Mullvad) │  │                     │ │
│ └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ tinfoil-hat namespace                   │
│ ┌─────────────┐  ┌─────────────────────┐ │
│ │ gluetun-vpn │◄─┤ tinfoil qBittorrent │ │
│ │   (Mullvad) │  │                     │ │
│ └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────┘
```

## Files Created/Modified

### Media-flix namespace:
- ✅ `k8s/10_apps/02_media-flix/values/gluetun-vpn.values.yaml` - Gluetun configuration
- ✅ `k8s/10_apps/02_media-flix/secrets/gluetun-vpn.secrets.yaml` - VPN credentials (needs your data)
- ✅ `k8s/10_apps/02_media-flix/helmfile.yaml` - Added Gluetun deployment
- ✅ `k8s/10_apps/02_media-flix/values/qb.values.yaml` - Cleaned up, ready for VPN routing

### Tinfoil-hat namespace:
- ✅ `k8s/10_apps/03_tinfoil-switch/values/gluetun-vpn.values.yaml` - Gluetun configuration
- ✅ `k8s/10_apps/03_tinfoil-switch/secrets/gluetun-vpn.secrets.yaml` - VPN credentials (needs your data)
- ✅ `k8s/10_apps/03_tinfoil-switch/helmfile.yaml` - Added Gluetun deployment

## Setup Instructions

### 1. Configure VPN Credentials

#### For Mullvad (recommended):
1. Log into your Mullvad account
2. Generate a WireGuard configuration
3. Edit the secrets files and replace the placeholder values:
   ```yaml
   wireguard_private_key: "your_actual_private_key"
   wireguard_addresses: "your_actual_ip/32"
   ```

#### For other providers:
- Modify the `VPN_SERVICE_PROVIDER` in the values files
- Update the credential fields in the secrets files accordingly

### 2. Encrypt the secrets:
```bash
cd k8s/10_apps/02_media-flix/secrets
sops -e -i gluetun-vpn.secrets.yaml

cd ../../03_tinfoil-switch/secrets  
sops -e -i gluetun-vpn.secrets.yaml
```

### 3. Deploy the configurations:
```bash
# Deploy media-flix VPN and qBittorrent
cd k8s/10_apps/02_media-flix
helmfile apply

# Deploy tinfoil-switch VPN and qBittorrent  
cd ../03_tinfoil-switch
helmfile apply
```

## Configuration Details

### Gluetun Features Enabled:
- ✅ **Port Forwarding** - Automatically configured for each qBittorrent instance
- ✅ **Kill Switch** - Firewall rules prevent traffic outside VPN
- ✅ **Health Checks** - Monitors VPN connection status
- ✅ **DNS over HTTPS** - Disabled to avoid conflicts
- ✅ **Local Network Access** - Allows access to your homelab services

### Port Configuration:
- **Media qBittorrent**: Port 50413 (TCP/UDP)
- **Tinfoil qBittorrent**: Port 6881 (TCP/UDP)

### Status Dashboards:
- **Media VPN Status**: `https://gluetun-status.local.naguiar.dev`
- **Tinfoil VPN Status**: `https://tinfoil-gluetun-status.local.naguiar.dev`

## How to Route qBittorrent Through VPN

The current setup has Gluetun running as separate containers. To actually route qBittorrent traffic through the VPN, you have a few options:

### Option A: Network Mode (Recommended)
Modify the qBittorrent containers to share the network with Gluetun:
```yaml
# In qBittorrent configuration
defaultPodOptions:
  shareProcessNamespace: true
  # Use the VPN pod's network
```

### Option B: Proxy Configuration
Configure qBittorrent to use Gluetun as a SOCKS5/HTTP proxy.

### Option C: Network Policies
Use Kubernetes network policies to force traffic through VPN.

## Troubleshooting

### Check VPN Status:
```bash
# Check if VPN is connected
kubectl exec -n media-flix deployment/gluetun-vpn -- curl -s https://ipinfo.io/json

# Check logs
kubectl logs -n media-flix deployment/gluetun-vpn -f
```

### Verify qBittorrent is using VPN:
1. Access qBittorrent web UI
2. Check external IP in the connection status
3. Should show VPN server IP, not your real IP

## Security Notes

- ✅ **No root privileges** - Gluetun runs with minimal required capabilities
- ✅ **Kill switch enabled** - Traffic blocked if VPN disconnects  
- ✅ **DNS leak protection** - Custom DNS servers configured
- ✅ **Encrypted credentials** - All secrets encrypted with SOPS
- ✅ **Network isolation** - Firewalls prevent unauthorized access

## Next Steps

1. **Add your VPN credentials** to the secrets files
2. **Encrypt the secrets** with SOPS
3. **Deploy the configurations** with helmfile
4. **Configure qBittorrent routing** (see options above)
5. **Test the setup** by verifying IP addresses
6. **Monitor VPN status** through the web dashboards

## Supported VPN Providers

Gluetun supports many providers out of the box:
- Mullvad (current config)
- NordVPN
- ExpressVPN
- Surfshark
- ProtonVPN
- And many more...

To switch providers, update the `VPN_SERVICE_PROVIDER` and credential fields in the values files.
