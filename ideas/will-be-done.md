# Blueprint: Will Be Done (Self-Hosted Task Manager)

## Overview & Homelab Value

[Will Be Done](https://will-be-done.app/) is a modern, local-first task manager with a visual weekly timeline.
It is open-source (AGPL), lightweight, and self-contained with SQLite storage, requiring no external database service.

### Key Capabilities & Architecture:
- **Local-First & Fast**: Clean, fluid UI with real-time WebSocket sync across devices.
- **Embedded Database**: Uses SQLite by default under `/var/lib/will-be-done/db`.
- **Minimal Resource Footprint**: Runs efficiently on Bun with ~128MiB RAM requested.

---

## Architectural Specifications

- **Target Namespace**: `will-be-done`
- **Directory**: `k8s/10_apps/18_will-be-done`
- **Ingress FQDNs**:
  - `https://wbd.local.naguiar.dev`
  - `https://wbd.naguiar.dev`
- **Database Required**: None (Embedded SQLite).
- **Storage**: PersistentVolumeClaim 1Gi on Longhorn mounted at `/var/lib/will-be-done`.

---

## Deployment & Security Considerations

> [!WARNING]
> **Open Registration**: Will Be Done (v0.14.0) currently does not offer an environment switch to disable public registration. Given that `wbd.naguiar.dev` is exposed via the Cloudflare tunnel wildcard, create your admin/primary user account immediately upon initial deployment.

> [!NOTE]
> **Backups**: Volume snapshots and recurring backups are handled automatically by Longhorn according to the cluster's default policy (`backup-daily`, `backup-weekly`, `backup-monthly` to the NAS backup store). Always ensure a healthy snapshot exists before upgrading container images, as database schema migrations are applied on start.
