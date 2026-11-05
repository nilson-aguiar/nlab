# Blueprint: Stirling-PDF (Self-Hosted PDF Swiss Army Knife)

## Overview & Homelab Value

[Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF) is a robust, locally hosted web application that allows you to perform virtually every conceivable operation on PDF files:
- Merge, split, rotate, and reorder pages.
- Compress file sizes while maintaining quality.
- Convert PDFs to/from images, Word, HTML, and Markdown.
- Add digital signatures, watermarks, page numbers, or stamps.
- Sanitize PDFs and strip metadata, passwords, and sensitive redactions.
- Perform optical character recognition (OCR) on image-only scans.

### Why It Fits Perfectly:
- **Privacy First**: Sensitive tax filings, employment contracts, identity documents, and financial records are processed strictly within your local cluster—never sent to commercial cloud converters.
- **Zero Database Required**: Completely stateless. No persistent volumes or database connections are needed.
- **Lightweight & Fast**: Uses ~150–250 MiB of RAM. Consumes negligible CPU when idle.

---

## Architectural Specifications

- **Target Namespace**: `stirling-pdf`
- **Suggested Directory**: `k8s/10_apps/15_stirling-pdf`
- **Ingress FQDNs**:
  - `https://pdf.local.naguiar.dev`
  - `https://pdf.naguiar.dev`
- **Database Required**: None (Stateless).
- **Storage**: Ephemeral `emptyDir` for scratch PDF processing.

---

## Manifest Templates

### 1. `k8s/10_apps/15_stirling-pdf/helmfile.yaml`

```yaml
repositories:
  - name: bjw-s
    url: ghcr.io/bjw-s-labs/helm
    oci: true

---
templates:
  bjw: &bjw
    namespace: stirling-pdf
    chart: bjw-s/app-template
    version: 5.0.1

releases:
  - name: stirling-pdf
    <<: *bjw
    values:
      - ./values/stirling-pdf.values.yaml
```

### 2. `k8s/10_apps/15_stirling-pdf/values/stirling-pdf.values.yaml`

```yaml
controllers:
  main:
    strategy: Recreate
    annotations:
      reloader.stakater.com/auto: "true"
    containers:
      app:
        image:
          repository: frooodle/s-pdf
          tag: 0.44.0
          pullPolicy: IfNotPresent
        env:
          TZ: Europe/Amsterdam
          SERVER_PORT: &port 8080
          DOCKER_ENABLE_SECURITY: "false" # Set true if you want internal user logins
          INSTALL_BOOK_AND_ADVANCED_HTML_OPS: "false"
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
          startup:
            enabled: true
            port: *port
            spec:
              failureThreshold: 30
              periodSeconds: 5
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
  tmp:
    type: emptyDir
    globalMounts:
      - path: /tmp

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
          - match: Host(`pdf.local.naguiar.dev`) || Host(`pdf.naguiar.dev`)
            kind: Rule
            services:
              - name: stirling-pdf
                port: *port
        tls:
          secretName: certificate-tls
```

### 3. `k8s/05_cluster-features/05_argo-cd/applications/stirling-pdf.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: stirling-pdf
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/nilson-aguiar/nlab.git
    targetRevision: main
    path: k8s/10_apps/15_stirling-pdf
    plugin:
      name: helmfile
  destination:
    server: https://kubernetes.default.svc
    namespace: stirling-pdf
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

- [x] Create directory: `mkdir -p k8s/10_apps/15_stirling-pdf/values`.
- [x] Save `helmfile.yaml` and `values/stirling-pdf.values.yaml`.
- [x] Add `stirling-pdf.yaml` to `k8s/05_cluster-features/05_argo-cd/applications/` and register in `kustomization.yaml`.
- [x] Commit, push, and let ArgoCD deploy.
