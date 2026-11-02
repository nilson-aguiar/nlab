# Blueprint: Linkwarden (Collaborative Bookmark & Webpage Archiver)

## Overview & Homelab Value

[Linkwarden](https://linkwarden.app/) is a self-hosted, open-source collaborative bookmark manager that archives full web pages so you never suffer from dead links or paywalled content you read in the past.

### Why It Fits Perfectly:
- **True Archiving**: Unlike browser bookmarks, Linkwarden saves a full screenshot, responsive PDF, and readable HTML snapshot of every link you save.
- **Zero AI Requirement**: Uses standard browser rendering (Playwright) to save pages directly on CPU.
- **Database Synergy**: Powered natively by PostgreSQL; hooks cleanly into your HA **CloudNativePG** cluster.
- **Lightweight**: Low memory consumption (~120–200 MiB RAM). Browser extensions exist for Chrome, Firefox, Safari, and edge mobile sharing.

---

## Architectural Specifications

- **Target Namespace**: `linkwarden`
- **Suggested Directory**: `k8s/10_apps/14_linkwarden`
- **Ingress FQDNs**:
  - `https://linkwarden.local.naguiar.dev`
  - `https://linkwarden.naguiar.dev`
- **Backend Database**: CloudNativePG (`postgres-rw.cloudnative-pg.svc.cluster.local:5432/linkwarden`)
- **Storage**: Longhorn PVC (`ReadWriteOnce`, 10Gi) for PDF/screenshot asset storage.

---

## Prerequisites (CloudNativePG Database Reflection)

Add `linkwarden` to the Reflector annotations in:
[k8s/05_cluster-features/01_database/postgres-cluster/cluster.yaml](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/k8s/05_cluster-features/01_database/postgres-cluster/cluster.yaml)

```yaml
reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "...,linkwarden"
reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "...,linkwarden"
```

---

## Manifest Templates

### 1. `k8s/10_apps/14_linkwarden/helmfile.yaml`

```yaml
repositories:
  - name: bjw-s
    url: ghcr.io/bjw-s-labs/helm
    oci: true

---
templates:
  bjw: &bjw
    namespace: linkwarden
    chart: bjw-s/app-template
    version: 5.0.1

releases:
  - name: linkwarden
    <<: *bjw
    values:
      - ./values/linkwarden.values.yaml
    secrets:
      - ./secrets/linkwarden.secrets.yaml
```

### 2. `k8s/10_apps/14_linkwarden/values/linkwarden.values.yaml`

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
          INIT_POSTGRES_USER: "linkwarden"
          INIT_POSTGRES_DBNAME: "linkwarden"
          INIT_POSTGRES_PASS:
            valueFrom:
              secretKeyRef:
                name: linkwarden
                key: DATABASE_PASSWORD
    containers:
      app:
        image:
          repository: ghcr.io/linkwarden/linkwarden
          tag: v2.9.3
          pullPolicy: IfNotPresent
        env:
          TZ: Europe/Amsterdam
          NEXTAUTH_URL: "https://linkwarden.local.naguiar.dev"
          DATABASE_URL: "postgresql://linkwarden:$(DATABASE_PASSWORD)@postgres-rw.cloudnative-pg.svc.cluster.local:5432/linkwarden"
          AUTOSCROLL_TIMEOUT: 60
        envFrom:
          - secretRef:
              name: linkwarden
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
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 1000m
            memory: 512Mi

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
      - path: /data/data

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
          - match: Host(`linkwarden.local.naguiar.dev`) || Host(`linkwarden.naguiar.dev`)
            kind: Rule
            services:
              - name: linkwarden
                port: *port
        tls:
          secretName: certificate-tls
```

### 3. `k8s/10_apps/14_linkwarden/secrets/linkwarden.secrets.yaml` (Template)

```yaml
# Encrypt with: sops -e -i k8s/10_apps/14_linkwarden/secrets/linkwarden.secrets.yaml
secrets:
  linkwarden:
    enabled: true
    stringData:
      NEXTAUTH_SECRET: "<REPLACE_WITH_A_RANDOM_32_CHAR_SECRET>"
      DATABASE_PASSWORD: "<REPLACE_WITH_STRONG_DB_PASSWORD>"
```

### 4. `k8s/05_cluster-features/05_argo-cd/applications/linkwarden.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: linkwarden
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/nilson-aguiar/nlab.git
    targetRevision: main
    path: k8s/10_apps/14_linkwarden
    plugin:
      name: helmfile
  destination:
    server: https://kubernetes.default.svc
    namespace: linkwarden
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

- [ ] Add `linkwarden` to Reflector annotations in `cluster.yaml`.
- [ ] Create directory: `mkdir -p k8s/10_apps/14_linkwarden/{values,secrets}`.
- [ ] Add `helmfile.yaml` and `values/linkwarden.values.yaml`.
- [ ] Fill in `secrets/linkwarden.secrets.yaml` and encrypt with SOPS.
- [ ] Add `linkwarden.yaml` to `k8s/05_cluster-features/05_argo-cd/applications/` and register in `kustomization.yaml`.
- [ ] Commit, push, and let ArgoCD deploy.
