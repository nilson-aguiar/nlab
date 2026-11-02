# Blueprint: Paperless-ngx (Document Management & OCR)

## Overview & Homelab Value

[Paperless-ngx](https://docs.paperless-ngx.com/) transforms physical document clutter into a searchable, organized digital archive. It is ideal for contracts, bills, tax documents, medical paperwork, receipts, and appliance manuals.

### Why It Fits Perfectly:
- **Zero AI / Pure CPU**: Uses battle-tested **Tesseract OCR** (running entirely on CPU with no GPU or LLM dependencies).
- **Automated Ingestion**:
  - Monitors a `consume/` directory on your Synology NAS (e.g., your network scanner or mobile uploads).
  - Directly polls an email inbox (IMAP) to extract attachments automatically.
  - Full-text search across all PDF pages in fractions of a second.
- **Direct CloudNativePG Integration**: Uses the existing HA PostgreSQL cluster instead of managing a separate database container.

---

## Architectural Specifications

- **Target Namespace**: `paperless`
- **Suggested Directory**: `k8s/10_apps/13_paperless`
- **Ingress FQDNs**:
  - `https://paperless.local.naguiar.dev`
  - `https://paperless.naguiar.dev`
- **Backend Services**:
  - **Database**: CloudNativePG (`postgres-rw.cloudnative-pg.svc.cluster.local:5432/paperless`)
  - **Message Broker / Cache**: Valkey / Redis (integrated into pod)
- **Storage Tiering**:
  - **Data / Index**: Longhorn PVC (`ReadWriteOnce`, 10Gi) for search indices and thumbnails.
  - **Media / Archive**: Synology NFS (`secondary` or `backup` storageClass) for persistent original documents.
  - **Consume**: Synology NFS for incoming scans.

---

## Prerequisites (CloudNativePG Database Reflection)

Paperless requires the shared `postgres-superuser` secret to run the initContainer.

Add `paperless` to the Reflector annotations in:
[k8s/05_cluster-features/01_database/postgres-cluster/cluster.yaml](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/k8s/05_cluster-features/01_database/postgres-cluster/cluster.yaml)

```yaml
reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "n8n,media-flix,affine,vaultwarden,nbot,home-assistant,monitoring,paperless"
reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "n8n,media-flix,affine,vaultwarden,nbot,home-assistant,monitoring,paperless"
```

---

## Manifest Templates

### 1. `k8s/10_apps/13_paperless/helmfile.yaml`

```yaml
repositories:
  - name: bjw-s
    url: ghcr.io/bjw-s-labs/helm
    oci: true

---
templates:
  bjw: &bjw
    namespace: paperless
    chart: bjw-s/app-template
    version: 5.0.1

releases:
  - name: paperless
    <<: *bjw
    values:
      - ./values/paperless.values.yaml
    secrets:
      - ./secrets/paperless.secrets.yaml
```

### 2. `k8s/10_apps/13_paperless/values/paperless.values.yaml`

```yaml
controllers:
  main:
    strategy: Recreate
    annotations:
      reloader.stakater.com/auto: "true"
    initContainers:
      init-db:
        image:
          repository: ghcr.io/home-operations/postgres-init
          tag: 18
        env:
          INIT_POSTGRES_SUPER_PASS:
            valueFrom:
              secretKeyRef:
                name: postgres-superuser
                key: password
          INIT_POSTGRES_HOST: "postgres-rw.cloudnative-pg.svc.cluster.local"
          INIT_POSTGRES_USER: "paperless"
          INIT_POSTGRES_DBNAME: "paperless"
          INIT_POSTGRES_PASS:
            valueFrom:
              secretKeyRef:
                name: paperless
                key: PAPERLESS_DBPASS
    containers:
      app:
        image:
          repository: ghcr.io/paperless-ngx/paperless-ngx
          tag: 2.14.7
          pullPolicy: IfNotPresent
        env:
          TZ: Europe/Amsterdam
          PAPERLESS_PORT: &port 8000
          PAPERLESS_URL: "https://paperless.local.naguiar.dev"
          PAPERLESS_REDIS: "redis://localhost:6379"
          PAPERLESS_DBENGINE: "postgresql"
          PAPERLESS_DBHOST: "postgres-rw.cloudnative-pg.svc.cluster.local"
          PAPERLESS_DBPORT: "5432"
          PAPERLESS_DBNAME: "paperless"
          PAPERLESS_DBUSER: "paperless"
          PAPERLESS_OCR_LANGUAGE: "eng+nld+por"
          PAPERLESS_TASK_WORKERS: 2
          PAPERLESS_WEBSERVER_WORKERS: 2
          PAPERLESS_TIME_ZONE: Europe/Amsterdam
        envFrom:
          - secretRef:
              name: paperless
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
            cpu: 100m
            memory: 384Mi
          limits:
            cpu: 1500m
            memory: 1024Mi

      valkey:
        image:
          repository: valkey/valkey
          tag: 8.0-alpine
          pullPolicy: IfNotPresent
        ports:
          - name: redis
            containerPort: 6379
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
  data:
    enabled: true
    type: persistentVolumeClaim
    accessMode: ReadWriteOnce
    size: 10Gi
    storageClass: longhorn
    globalMounts:
      - path: /usr/src/paperless/data

  media:
    enabled: true
    type: persistentVolumeClaim
    accessMode: ReadWriteMany
    size: 50Gi
    storageClass: secondary
    globalMounts:
      - path: /usr/src/paperless/media

  consume:
    enabled: true
    type: persistentVolumeClaim
    accessMode: ReadWriteMany
    size: 10Gi
    storageClass: secondary
    globalMounts:
      - path: /usr/src/paperless/consume

  export:
    enabled: true
    type: persistentVolumeClaim
    accessMode: ReadWriteMany
    size: 20Gi
    storageClass: backup
    globalMounts:
      - path: /usr/src/paperless/export

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
          - match: Host(`paperless.local.naguiar.dev`) || Host(`paperless.naguiar.dev`)
            kind: Rule
            services:
              - name: paperless
                port: *port
        tls:
          secretName: certificate-tls
```

### 3. `k8s/10_apps/13_paperless/secrets/paperless.secrets.yaml` (Template)

```yaml
# Encrypt with: sops -e -i k8s/10_apps/13_paperless/secrets/paperless.secrets.yaml
secrets:
  paperless:
    enabled: true
    stringData:
      PAPERLESS_SECRET_KEY: "<REPLACE_WITH_A_LONG_RANDOM_SECRET_KEY>"
      PAPERLESS_ADMIN_USER: "admin"
      PAPERLESS_ADMIN_PASSWORD: "<REPLACE_WITH_STRONG_ADMIN_PASSWORD>"
      PAPERLESS_DBPASS: "<REPLACE_WITH_PAPERLESS_DB_PASSWORD>"
```

### 4. `k8s/05_cluster-features/05_argo-cd/applications/paperless.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: paperless
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/nilson-aguiar/nlab.git
    targetRevision: main
    path: k8s/10_apps/13_paperless
    plugin:
      name: helmfile
  destination:
    server: https://kubernetes.default.svc
    namespace: paperless
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

- [ ] Update `cluster.yaml` to include `paperless` in the Reflector namespace lists.
- [ ] Create directory: `mkdir -p k8s/10_apps/13_paperless/{values,secrets}`.
- [ ] Populate `helmfile.yaml` and `values/paperless.values.yaml`.
- [ ] Generate a random `PAPERLESS_SECRET_KEY`, fill in `secrets/paperless.secrets.yaml`, and encrypt with SOPS.
- [ ] Add `paperless.yaml` to `k8s/05_cluster-features/05_argo-cd/applications/` and register in `kustomization.yaml`.
- [ ] Commit, push to feature branch, and let ArgoCD sync.
