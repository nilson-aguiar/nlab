# Design Doc: Gluetun VPN Sidecar for qBittorrent

## Purpose
Integrate Gluetun as a VPN sidecar for qBittorrent instances in the `nlab` cluster to ensure all torrent traffic is routed through a secure VPN tunnel with an automatic kill-switch.

## Architecture
- **Pattern**: Sidecar (Containers share the same network namespace/Pod).
- **Network Flow**: 
    - Gluetun establishes the VPN connection (`tun0`).
    - qBittorrent traffic is routed through `tun0`.
    - Local network access for WebUI is maintained via standard K8s services.

## Components

### 1. Secrets Management
- **File**: `k8s/10_apps/03_tinfoil-switch/secrets/vpn.values.secret.yaml`
- **Content**: Encrypted VPN credentials (Provider, Username, Password, Server details).
- **Tooling**: SOPS for encryption.

### 2. Chart Modifications (`tinfoil-hat`)
- **values.yaml**: Add a `gluetun` section to toggle the sidecar and configure VPN provider settings.
- **qbittorrent-deployment.yaml**:
    - Add `gluetun` container.
    - Set `securityContext.capabilities.add: ["NET_ADMIN"]` for Gluetun.
    - Mount `/dev/net/tun` host device (or verify K3s availability).
    - Link `envFrom` to the VPN secret.

### 3. Networking & Ingress
- **Binding**: Ensure qBittorrent WebUI binds to `0.0.0.0` or `127.0.0.1` (depending on proxy needs).
- **Service**: Point to the existing WebUI port.
- **Kill-switch**: Verified by Gluetun's internal firewall rules which block non-VPN egress.

## Success Criteria
- qBittorrent instance starts and stays in "Ready" state only when VPN is connected.
- `curl ifconfig.me` from inside the qBittorrent container returns the VPN IP, not the home IP.
- WebUI remains accessible via Traefik ingress.
