# Blueprint: IT-Tools (Sysadmin & Developer Toolbox)

## Overview & Homelab Value

[IT-Tools](https://it-tools.tech/) is a collection of handy online utilities for developers, homelabbers, and sysadmins. Having a self-hosted instance ensures that your tokens, private keys, hashes, JSON payloads, and sensitive configurations never leave your internal network.

### Included Tools:
- **Crypto & Security**: Token generator, Hash (MD5, SHA, Bcrypt, Argon2), UUID v4/v7 generator, RSA key-pair generator, Password strength analyzer.
- **Converters**: JSON <-> YAML, Base64 encoder/decoder, Docker Run to Docker Compose, Integer base converter, Epoch timestamp converter.
- **Web & Network**: JWT decoder, URL encoder/decoder, IPv4 subnet calculator, MAC address lookup, HTTP status code reference.
- **Development**: Crontab generator & parser, Regex tester, Markdown previewer, Git cheat-sheet.

### Why It Fits Perfectly:
- **Ultra-Lightweight**: Only ~15–20 MiB of RAM. It runs as a static Single Page Application (SPA) inside an Nginx container.
- **Zero Dependencies**: No database, no cache, no persistence required.
- **Privacy Assurance**: Eliminates the need to paste sensitive configs or tokens into random third-party web tools.

---

## Architectural Specifications

- **Target Namespace**: `it-tools`
- **Suggested Directory**: `k8s/10_apps/17_it-tools`
- **Ingress FQDNs**:
  - `https://it-tools.local.naguiar.dev`
  - `https://it-tools.naguiar.dev`
- **Database Required**: None (Stateless).
- **Storage Required**: None.

---

## Manifest Templates

### 1. `k8s/10_apps/17_it-tools/helmfile.yaml`

```yaml
repositories:
  - name: bjw-s
    url: ghcr.io/bjw-s-labs/helm
    oci: true

---
templates:
  bjw: &bjw
    namespace: it-tools
    chart: bjw-s/app-template
    version: 5.0.1

releases:
  - name: it-tools
    <<: *bjw
    values:
      - ./values/it-tools.values.yaml
```

### 2. `k8s/10_apps/17_it-tools/values/it-tools.values.yaml`

```yaml
controllers:
  main:
    strategy: Recreate
    containers:
      app:
        image:
          repository: ghcr.io/corentinth/it-tools
          tag: 2024.10.22-7ca59a3
          pullPolicy: IfNotPresent
        ports:
          - name: http
            containerPort: &port 80
        probes:
          liveness:
            enabled: true
            port: *port
          readiness:
            enabled: true
            port: *port
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 64Mi

service:
  app:
    controller: main
    ports:
      http:
        port: *port

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
          - match: Host(`it-tools.local.naguiar.dev`) || Host(`it-tools.naguiar.dev`)
            kind: Rule
            services:
              - name: it-tools
                port: *port
        tls:
          secretName: certificate-tls
```

### 3. `k8s/05_cluster-features/05_argo-cd/applications/it-tools.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: it-tools
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/nilson-aguiar/nlab.git
    targetRevision: main
    path: k8s/10_apps/17_it-tools
    plugin:
      name: helmfile
  destination:
    server: https://kubernetes.default.svc
    namespace: it-tools
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

- [ ] Create directory: `mkdir -p k8s/10_apps/17_it-tools/values`.
- [ ] Save `helmfile.yaml` and `values/it-tools.values.yaml`.
- [ ] Add `it-tools.yaml` to `k8s/05_cluster-features/05_argo-cd/applications/` and register in `kustomization.yaml`.
- [ ] Commit, push, and let ArgoCD sync.
