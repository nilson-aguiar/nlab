# Blueprint: Homepage (Central Homelab Dashboard)

## Overview & Homelab Value

[Homepage](https://gethomepage.dev/) is an ultra-fast, modern, highly customizable dashboard for self-hosted services.
Currently, your cluster hosts over 15 distinct user-facing applications (Plex, Jellyfin, Sonarr, Radarr, Actual Budget, AFFiNE, Vaultwarden, Komga, Home Assistant, ArgoCD, Grafana, etc.). Homepage unifies all of them into a single high-performance landing portal.

### Why It Fits Perfectly:
- **Resource Footprint**: Minimal (~50–100 MiB RAM, ~50m CPU at peak). Zero background worker bloat.
- **Native Widget Integrations**: Directly displays live stats from your existing stack:
  - **ArgoCD**: Total apps, synced status, degraded apps.
  - **VictoriaMetrics / Kubernetes**: Cluster CPU, memory, and node health.
  - **Pi-hole**: DNS queries today, block rate percentage.
  - **qBittorrent / Media**: Current download/upload speed, active torrents.
  - **Sonarr & Radarr**: Upcoming calendar releases and queue.
  - **Plex & Jellyfin**: Active streams and now-playing cards.
  - **Actual Budget**: Account balances and net-worth summary.
  - **Home Assistant**: Weather, room temperatures, smart device status.

---

## Architectural Specifications

- **Target Namespace**: `homepage`
- **Suggested Directory**: `k8s/10_apps/12_homepage`
- **Ingress FQDNs**:
  - `https://home.local.naguiar.dev` (Local network / Pi-hole)
  - `https://home.naguiar.dev` (External / Cloudflare Tunnel / Tailscale)
- **Persistence**: Longhorn PVC (1Gi) or ConfigMaps for config files (`settings.yaml`, `services.yaml`, `widgets.yaml`, `bookmarks.yaml`).
- **Database Required**: None (File/YAML based).

---

## Manifest Templates

### 1. `k8s/10_apps/12_homepage/helmfile.yaml`

```yaml
repositories:
  - name: bjw-s
    url: ghcr.io/bjw-s-labs/helm
    oci: true

---
templates:
  bjw: &bjw
    namespace: homepage
    chart: bjw-s/app-template
    version: 5.0.1

releases:
  - name: homepage
    <<: *bjw
    values:
      - ./values/homepage.values.yaml
    secrets:
      - ./secrets/homepage.secrets.yaml
```

### 2. `k8s/10_apps/12_homepage/values/homepage.values.yaml`

```yaml
controllers:
  main:
    strategy: Recreate
    annotations:
      reloader.stakater.com/auto: "true"
    containers:
      app:
        image:
          repository: ghcr.io/gethomepage/homepage
          tag: v0.10.9
          pullPolicy: IfNotPresent
        env:
          TZ: Europe/Amsterdam
        envFrom:
          - secretRef:
              name: homepage
        ports:
          - name: http
            containerPort: &port 3000
        probes:
          liveness:
            enabled: true
            port: *port
          readiness:
            enabled: true
            port: *port
          startup:
            enabled: true
            port: *port
            spec:
              failureThreshold: 30
              periodSeconds: 5
        resources:
          requests:
            cpu: 20m
            memory: 64Mi
          limits:
            memory: 256Mi

service:
  app:
    controller: main
    ports:
      http:
        port: *port

persistence:
  config:
    enabled: true
    type: persistentVolumeClaim
    accessMode: ReadWriteOnce
    size: 1Gi
    storageClass: longhorn
    globalMounts:
      - path: /app/config

rawResources:
  ingress-route:
    enabled: true
    manifest:
      apiVersion: traefik.io/v1alpha1
      kind: IngressRoute
      metadata:
        annotations:
          external-dns.alpha.kubernetes.io/target: 192.168.1.200
          kubernetes.io/ingress.class: traefik-external
      spec:
        entryPoints:
          - websecure
        routes:
          - match: Host(`home.local.naguiar.dev`) || Host(`home.naguiar.dev`)
            kind: Rule
            services:
              - name: homepage
                port: *port
        tls:
          secretName: certificate-tls
```

### 3. `k8s/10_apps/12_homepage/secrets/homepage.secrets.yaml` (Template)

```yaml
# Encrypt with: sops -e -i k8s/10_apps/12_homepage/secrets/homepage.secrets.yaml
secrets:
  homepage:
    enabled: true
    stringData:
      HOMEPAGE_VAR_SONARR_API_KEY: "<REPLACE_WITH_SONARR_API_KEY>"
      HOMEPAGE_VAR_RADARR_API_KEY: "<REPLACE_WITH_RADARR_API_KEY>"
      HOMEPAGE_VAR_QBITTORRENT_USERNAME: "<REPLACE_WITH_QB_USER>"
      HOMEPAGE_VAR_QBITTORRENT_PASSWORD: "<REPLACE_WITH_QB_PASSWORD>"
      HOMEPAGE_VAR_PIHOLE_API_TOKEN: "<REPLACE_WITH_PIHOLE_WEB_PASSWORD_OR_HASH>"
      HOMEPAGE_VAR_ARGOCD_AUTH_TOKEN: "<REPLACE_WITH_ARGOCD_TOKEN>"
```

### 4. Sample Homepage Service Config (`services.yaml`)

This configuration leverages cluster internal DNS (`<service>.<namespace>.svc.cluster.local:<port>`):

```yaml
- Infrastructure:
    - ArgoCD:
        icon: argocd.png
        href: https://argocd.local.naguiar.dev
        description: GitOps Delivery Engine
        widget:
          type: argocd
          url: http://argo-cd-argocd-server.argocd.svc.cluster.local:80
          key: "{{HOMEPAGE_VAR_ARGOCD_AUTH_TOKEN}}"

    - Pi-hole:
        icon: pi-hole.png
        href: http://192.168.1.121:8080/admin
        description: Local DNS & Ad-blocking
        widget:
          type: pihole
          url: http://pihole-dns.pi-hole.svc.cluster.local:80
          key: "{{HOMEPAGE_VAR_PIHOLE_API_TOKEN}}"

- Media & Downloads:
    - Sonarr:
        icon: sonarr.png
        href: https://sonarr.local.naguiar.dev
        widget:
          type: sonarr
          url: http://sonarr.media-flix.svc.cluster.local:8989
          key: "{{HOMEPAGE_VAR_SONARR_API_KEY}}"

    - Radarr:
        icon: radarr.png
        href: https://radarr.local.naguiar.dev
        widget:
          type: radarr
          url: http://radarr.media-flix.svc.cluster.local:7878
          key: "{{HOMEPAGE_VAR_RADARR_API_KEY}}"

    - qBittorrent:
        icon: qbittorrent.png
        href: https://qb.local.naguiar.dev
        widget:
          type: qbittorrent
          url: http://media-qb.media-flix.svc.cluster.local:8080
          username: "{{HOMEPAGE_VAR_QBITTORRENT_USERNAME}}"
          password: "{{HOMEPAGE_VAR_QBITTORRENT_PASSWORD}}"
```

### 5. `k8s/05_cluster-features/05_argo-cd/applications/homepage.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homepage
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/nilson-aguiar/nlab.git
    targetRevision: main
    path: k8s/10_apps/12_homepage
    plugin:
      name: helmfile
  destination:
    server: https://kubernetes.default.svc
    namespace: homepage
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - SkipDryRunOnMissingResource=true
```

---

## Rollout Checklist

- [ ] Create directory: `mkdir -p k8s/10_apps/12_homepage/{values,secrets}`.
- [ ] Save the `helmfile.yaml` and `values/homepage.values.yaml`.
- [ ] Populate API tokens in `secrets/homepage.secrets.yaml` and run `sops -e -i`.
- [ ] Add `homepage.yaml` to `k8s/05_cluster-features/05_argo-cd/applications/` and register in `kustomization.yaml`.
- [ ] Commit, push to feature branch, and let ArgoCD sync.
