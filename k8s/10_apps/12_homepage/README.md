# Homepage (Central Homelab Dashboard)

[Homepage](https://gethomepage.dev/) is an ultra-fast, modern dashboard for self-hosted services deployed in the `homepage` namespace.

- **Internal Ingress**: `https://home.local.naguiar.dev`
- **External Ingress**: `https://home.naguiar.dev`

---

## Current Setup

Currently, Homepage is deployed as a clean, responsive homelab launchpad:
- **Kubernetes Cluster Widget**: Active out-of-the-box using the cluster's internal `ServiceAccount` and `ClusterRole`. Displays live CPU, memory, and node health for `homelab-0`, `homelab-1`, and `homelab-2`.
- **Application Cards**: Pre-configured with official icons and direct links for all services in the cluster.
- **GitOps Declarative Config**: Configuration (`settings.yaml`, `services.yaml`, `widgets.yaml`, `bookmarks.yaml`, `kubernetes.yaml`) is managed in Git inside `values/homepage.values.yaml` and mounted cleanly via `subPath`.

---

## How to Enable Live API Widgets

To turn an application card into an interactive widget showing live stats (e.g. download speeds, upcoming media, DNS blocks, sync status), follow these two steps:

1. **Add your API Key to the encrypted secrets file**
2. **Add the `widget:` block to `values/homepage.values.yaml`**

---

### Step 1: Edit Secrets with SOPS

Open and decrypt the secrets file:

```bash
sops k8s/10_apps/12_homepage/secrets/homepage.secrets.yaml
```

Fill in the appropriate `HOMEPAGE_VAR_*` value, save, and exit. SOPS will automatically encrypt the file with your age key.

---

### Step 2: How to Generate API Keys & Add Widgets

#### 1. ArgoCD
* **What it shows**: Total applications, count of `Synced` apps, and alert status for `Degraded` or `OutOfSync` apps.
* **How to get the token**:
  - In ArgoCD UI, go to **Settings** &rarr; **Accounts** (or your User Profile) &rarr; **Tokens** &rarr; click **Generate Token**.
* **Secret key**: `HOMEPAGE_VAR_ARGOCD_AUTH_TOKEN`
* **Widget configuration** (in `services.yaml` under `ArgoCD`):
  ```yaml
  widget:
    type: argocd
    url: http://argocd-server.argocd.svc.cluster.local:80
    key: '{{ "{{" }}HOMEPAGE_VAR_ARGOCD_AUTH_TOKEN{{ "}}" }}'
  ```

---

#### 2. Pi-hole
* **What it shows**: Total DNS queries today, queries blocked, percentage blocked, and total domains blocked.
* **How to get the token**:
  - In Pi-hole Admin UI, go to **Settings** &rarr; **API / Web interface** &rarr; click **Show API token**.
* **Secret key**: `HOMEPAGE_VAR_PIHOLE_API_TOKEN`
* **Widget configuration** (in `services.yaml` under `Pi-hole`):
  ```yaml
  widget:
    type: pihole
    url: http://pihole-web.pihole-system.svc.cluster.local:80
    key: '{{ "{{" }}HOMEPAGE_VAR_PIHOLE_API_TOKEN{{ "}}" }}'
  ```

---

#### 3. Sonarr
* **What it shows**: Episodes airing today/this week, queued downloads, and missing episodes.
* **How to get the key**:
  - In Sonarr UI: **Settings** &rarr; **General** &rarr; **Security** &rarr; copy **API Key**.
* **Secret key**: `HOMEPAGE_VAR_SONARR_API_KEY`
* **Widget configuration** (in `services.yaml` under `Sonarr`):
  ```yaml
  widget:
    type: sonarr
    url: http://sonarr.media-flix.svc.cluster.local:8989
    key: '{{ "{{" }}HOMEPAGE_VAR_SONARR_API_KEY{{ "}}" }}'
  ```

---

#### 4. Radarr
* **What it shows**: Upcoming movie releases, download queue, and wanted/missing movie counts.
* **How to get the key**:
  - In Radarr UI: **Settings** &rarr; **General** &rarr; **Security** &rarr; copy **API Key**.
* **Secret key**: `HOMEPAGE_VAR_RADARR_API_KEY`
* **Widget configuration** (in `services.yaml` under `Radarr`):
  ```yaml
  widget:
    type: radarr
    url: http://radarr.media-flix.svc.cluster.local:7878
    key: '{{ "{{" }}HOMEPAGE_VAR_RADARR_API_KEY{{ "}}" }}'
  ```

---

#### 5. qBittorrent
* **What it shows**: Real-time download & upload speeds (e.g. `15 MB/s`), active torrents downloading/seeding.
* **How to get credentials**:
  - The Web UI username and password used to log into qBittorrent.
* **Secret keys**:
  - `HOMEPAGE_VAR_QBITTORRENT_USERNAME`
  - `HOMEPAGE_VAR_QBITTORRENT_PASSWORD`
* **Widget configuration** (in `services.yaml` under `qBittorrent`):
  ```yaml
  widget:
    type: qbittorrent
    url: http://media-qb.media-flix.svc.cluster.local:8080
    username: '{{ "{{" }}HOMEPAGE_VAR_QBITTORRENT_USERNAME{{ "}}" }}'
    password: '{{ "{{" }}HOMEPAGE_VAR_QBITTORRENT_PASSWORD{{ "}}" }}'
  ```

---

#### 6. Jellyfin
* **What it shows**: Active streams currently playing, user names, and transcode status.
* **How to get the key**:
  - In Jellyfin UI: **Dashboard** (Admin) &rarr; **API Keys** &rarr; click **+** to generate a key named `homepage`.
* **Secret key**: `HOMEPAGE_VAR_JELLYFIN_API_KEY`
* **Widget configuration** (in `services.yaml` under `Jellyfin`):
  ```yaml
  widget:
    type: jellyfin
    url: http://jellyfin.media-flix.svc.cluster.local:8096
    key: '{{ "{{" }}HOMEPAGE_VAR_JELLYFIN_API_KEY{{ "}}" }}'
  ```

---

#### 7. Prowlarr
* **What it shows**: Total active indexers, disabled indexers, and failed query count.
* **How to get the key**:
  - In Prowlarr UI: **Settings** &rarr; **General** &rarr; **Security** &rarr; copy **API Key**.
* **Secret key**: `HOMEPAGE_VAR_PROWLARR_API_KEY`
* **Widget configuration** (in `services.yaml` under `Prowlarr`):
  ```yaml
  widget:
    type: prowlarr
    url: http://prowlarr.media-flix.svc.cluster.local:9696
    key: '{{ "{{" }}HOMEPAGE_VAR_PROWLARR_API_KEY{{ "}}" }}'
  ```

---

#### 8. Overseerr
* **What it shows**: Pending media requests waiting for approval and processing counts.
* **How to get the key**:
  - In Overseerr UI: **Settings** &rarr; **General** &rarr; copy **API Key**.
* **Secret key**: `HOMEPAGE_VAR_SEERR_API_KEY`
* **Widget configuration** (in `services.yaml` under `Overseerr`):
  ```yaml
  widget:
    type: overseerr
    url: http://seerr.media-flix.svc.cluster.local:5055
    key: '{{ "{{" }}HOMEPAGE_VAR_SEERR_API_KEY{{ "}}" }}'
  ```

---

#### 9. Tautulli
* **What it shows**: Plex active stream counts, direct play vs transcode, and bandwidth usage.
* **How to get the key**:
  - In Tautulli UI: **Settings** &rarr; **Web Interface** &rarr; copy **API Key**.
* **Secret key**: `HOMEPAGE_VAR_TAUTULLI_API_KEY`
* **Widget configuration** (in `services.yaml` under `Tautulli`):
  ```yaml
  widget:
    type: tautulli
    url: http://tautulli.media-flix.svc.cluster.local:8181
    key: '{{ "{{" }}HOMEPAGE_VAR_TAUTULLI_API_KEY{{ "}}" }}'
  ```

---

#### 10. Home Assistant
* **What it shows**: Temperature, weather, or custom entity state summaries.
* **How to get the token**:
  - In Home Assistant: Click your **Profile** (bottom left) &rarr; **Security** tab &rarr; scroll to **Long-Lived Access Tokens** &rarr; click **Create Token** (name it `homepage`).
* **Secret key**: `HOMEPAGE_VAR_HASS_API_KEY`
* **Widget configuration** (in `services.yaml` under `Home Assistant`):
  ```yaml
  widget:
    type: homeassistant
    url: http://home-assistant.home-assistant.svc.cluster.local:8123
    key: '{{ "{{" }}HOMEPAGE_VAR_HASS_API_KEY{{ "}}" }}'
  ```

---

#### 11. Paperless-ngx
* **What it shows**: Total archived documents and inbox/unprocessed document queue count.
* **How to get the token**:
  - In Paperless-ngx UI: Click your **Username** (top right) &rarr; **My Profile** &rarr; **API Tokens** &rarr; **Create Token**.
* **Secret key**: `HOMEPAGE_VAR_PAPERLESS_API_KEY`
* **Widget configuration** (in `services.yaml` under `Paperless-ngx`):
  ```yaml
  widget:
    type: paperlessngx
    url: http://paperless.paperless.svc.cluster.local:8000
    key: '{{ "{{" }}HOMEPAGE_VAR_PAPERLESS_API_KEY{{ "}}" }}'
  ```

---

#### 12. Komga
* **What it shows**: Total books/comics, libraries, and unread book counts.
* **How to get credentials**:
  - Your Komga user credentials (can be a read-only account).
* **Secret keys**:
  - `HOMEPAGE_VAR_KOMGA_USERNAME`
  - `HOMEPAGE_VAR_KOMGA_PASSWORD`
* **Widget configuration** (in `services.yaml` under `Komga`):
  ```yaml
  widget:
    type: komga
    url: http://komga.reader.svc.cluster.local:8080
    username: '{{ "{{" }}HOMEPAGE_VAR_KOMGA_USERNAME{{ "}}" }}'
    password: '{{ "{{" }}HOMEPAGE_VAR_KOMGA_PASSWORD{{ "}}" }}'
  ```

---

### Step 3: Commit and Push

Whenever you update `secrets/homepage.secrets.yaml` or `values/homepage.values.yaml`:

```bash
git add k8s/10_apps/12_homepage/
git commit -m "feat(homepage): enable widgets for <services>"
git push
```

ArgoCD will automatically sync the changes, reload the deployment, and update the dashboard.
