# Blueprint: RomM & EmulatorJS (Retro Gaming Vault & Browser Play)

## Overview & Homelab Value

This blueprint pairs two complementary self-hosted gaming services to create a complete personal retro gaming arcade:
1. **[RomM (ROM Manager)](https://github.com/rommapp/romm)**: An elegant library manager that organizes, tags, and scans your ROM collections across retro systems (Game Boy, GBA, SNES, N64, PS1, PSP, Nintendo Switch, etc.). It scrapes rich cover art, screenshots, descriptions, and ratings from IGDB.
2. **[EmulatorJS](https://emulatorjs.org/)**: A lightweight in-browser retro game player powered by WebAssembly. It allows anyone on your network to play games instantly in a browser (on Mac, PC, iPad, or TV) with zero client installations, featuring full USB and Bluetooth gamepad support.

### Why It Fits Perfectly:
- **Client-Side Emulation**: EmulatorJS loads the emulator core and ROM into the user's browser via WebAssembly. The cluster only serves static assets and ROM files, requiring almost **zero server CPU**.
- **Shared NFS Storage**: Both services mount the same ROM library hosted on your Synology NAS (`secondary` storageClass).
- **Lightweight**: Combined memory footprint is ~120–150 MiB RAM.

---

## Architectural Specifications

- **Target Namespace**: `gaming`
- **Suggested Directory**: `k8s/10_apps/16_gaming`
- **Ingress FQDNs**:
  - RomM: `https://romm.local.naguiar.dev` / `https://romm.naguiar.dev`
  - EmulatorJS: `https://play.local.naguiar.dev` / `https://play.naguiar.dev`
- **Persistence**: Synology NFS (`secondary` storageClass) mounted at `/roms`.
- **Database**: SQLite (embedded on Longhorn PVC) or CloudNativePG.

---

## Manifest Templates

### 1. `k8s/10_apps/16_gaming/helmfile.yaml`

```yaml
repositories:
  - name: bjw-s
    url: ghcr.io/bjw-s-labs/helm
    oci: true

---
templates:
  bjw: &bjw
    namespace: gaming
    chart: bjw-s/app-template
    version: 5.0.1

releases:
  - name: romm
    <<: *bjw
    values:
      - ./values/romm.values.yaml
    secrets:
      - ./secrets/romm.secrets.yaml

  - name: emulatorjs
    <<: *bjw
    values:
      - ./values/emulatorjs.values.yaml
```

### 2. `k8s/10_apps/16_gaming/values/romm.values.yaml`

```yaml
controllers:
  main:
    strategy: Recreate
    annotations:
      reloader.stakater.com/auto: "true"
    containers:
      app:
        image:
          repository: ghcr.io/rommapp/romm
          tag: 3.7.3
          pullPolicy: IfNotPresent
        env:
          TZ: Europe/Amsterdam
          ROMM_PORT: &port 8080
          ROMM_BASE_PATH: "/"
          DB_ENGINE: "sqlite"
        envFrom:
          - secretRef:
              name: romm
        ports:
          - name: http
            containerPort: *port
        probes:
          liveness:
            enabled: true
            port: *port
          readiness:
            enabled: true
            port: *port
        resources:
          requests:
            cpu: 30m
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
    size: 2Gi
    storageClass: longhorn
    globalMounts:
      - path: /romm/database

  roms:
    enabled: true
    type: persistentVolumeClaim
    accessMode: ReadWriteMany
    size: 50Gi
    storageClass: secondary
    globalMounts:
      - path: /romm/library

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
          - match: Host(`romm.local.naguiar.dev`) || Host(`romm.naguiar.dev`)
            kind: Rule
            services:
              - name: romm
                port: *port
        tls:
          secretName: certificate-tls
```

### 3. `k8s/10_apps/16_gaming/values/emulatorjs.values.yaml`

```yaml
controllers:
  main:
    strategy: Recreate
    containers:
      app:
        image:
          repository: lscr.io/linuxserver/emulatorjs
          tag: 1.9.1
          pullPolicy: IfNotPresent
        env:
          TZ: Europe/Amsterdam
          PUID: "1000"
          PGID: "1000"
        ports:
          - name: http
            containerPort: &port 80
        resources:
          requests:
            cpu: 20m
            memory: 32Mi
          limits:
            memory: 128Mi

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
    size: 2Gi
    storageClass: longhorn
    globalMounts:
      - path: /config

  data:
    enabled: true
    type: persistentVolumeClaim
    accessMode: ReadWriteMany
    size: 50Gi
    storageClass: secondary
    globalMounts:
      - path: /data

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
          - match: Host(`play.local.naguiar.dev`) || Host(`play.naguiar.dev`)
            kind: Rule
            services:
              - name: emulatorjs
                port: *port
        tls:
          secretName: certificate-tls
```

### 4. `k8s/10_apps/16_gaming/secrets/romm.secrets.yaml` (Template)

```yaml
# Encrypt with: sops -e -i k8s/10_apps/16_gaming/secrets/romm.secrets.yaml
secrets:
  romm:
    enabled: true
    stringData:
      ROMM_AUTH_SECRET_KEY: "<REPLACE_WITH_RANDOM_SECRET_KEY>"
      IGDB_CLIENT_ID: "<OPTIONAL_IGDB_CLIENT_ID>"
      IGDB_CLIENT_SECRET: "<OPTIONAL_IGDB_CLIENT_SECRET>"
```

### 5. `k8s/05_cluster-features/05_argo-cd/applications/gaming.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gaming
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/nilson-aguiar/nlab.git
    targetRevision: main
    path: k8s/10_apps/16_gaming
    plugin:
      name: helmfile
  destination:
    server: https://kubernetes.default.svc
    namespace: gaming
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

- [ ] Create directory: `mkdir -p k8s/10_apps/16_gaming/{values,secrets}`.
- [ ] Save `helmfile.yaml`, `values/romm.values.yaml`, and `values/emulatorjs.values.yaml`.
- [ ] Generate secret key, populate `secrets/romm.secrets.yaml`, and encrypt with SOPS.
- [ ] Add `gaming.yaml` to `k8s/05_cluster-features/05_argo-cd/applications/` and register in `kustomization.yaml`.
- [ ] Commit, push, and let ArgoCD sync.
