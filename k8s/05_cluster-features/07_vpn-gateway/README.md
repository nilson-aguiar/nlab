# Gluetun VPN Gateway

This deployment provides a centralized VPN gateway for the cluster using Gluetun and NordVPN.

## Setup Instructions

1. **Extract your NordVPN Wireguard Private Key**:
   - NordVPN doesn't directly show the Wireguard private key in their dashboard. You can extract it using a tool like [nordpnv-wg-extract](https://github.com/v8u/nordvpn-wg-extract) or by using the NordVPN Linux client and running `sudo nordvpn set technology wireguard` followed by `sudo wg show nordlynx private-key`.

2. **Update the Secret**:
   - Open `secrets/nordvpn.secret.yaml`.
   - Replace `YOUR_NORDVPN_WIREGUARD_PRIVATE_KEY` with your actual key.
   - Encrypt the file using SOPS:
     ```bash
     sops -e -i secrets/nordvpn.secret.yaml
     ```

3. **Deploy**:
   - Run the deployment:
     ```bash
     helmfile -f helmfile.yaml apply
     ```

4. **Configure qBittorrent**:
   - In the qBittorrent Web UI, go to **Tools** -> **Options** -> **Connection**.
   - Under **Proxy Server**:
     - **Type**: `SOCKS5`
     - **Host**: `vpn-gateway.vpn-gateway.svc.cluster.local`
     - **Port**: `1080`
     - Check **Use proxy for peer connections**
     - Check **Force proxy for peer connections**
   - Go to **BitTorrent** tab:
     - Check **Enable Anonymous Mode**

## Verification

You can verify the VPN is working by running a curl command from within a pod using the proxy:
```bash
curl --socks5 vpn-gateway.vpn-gateway.svc.cluster.local:1080 ifconfig.me
```
The IP returned should be a NordVPN IP, not your home IP.
