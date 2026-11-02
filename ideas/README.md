# Homelab Expansion Ideas & Backlog

This directory contains production-ready implementation blueprints for proposed services to expand the `nlab` homelab cluster.

Each blueprint is tailored specifically to the infrastructure of this repository:
- **NixOS** 3-node HA Kubernetes cluster (`homelab-0`, `homelab-1`, `homelab-2`).
- **Resource Constraints**: Lightweight footprints (30MB – 400MB RAM), low idle CPU, zero AI/LLM overhead.
- **Deployment Standard**: GitOps managed via **ArgoCD**, declarative deployments with **Helmfile** and **`bjw-s/app-template: 5.0.1`**.
- **Persistence Strategy**: Longhorn for fast local block storage, Synology NAS NFS (`backup` and `secondary` storage classes) for bulk/media storage.
- **Shared Services**: **CloudNativePG** (HA PostgreSQL), **Traefik** IngressRoute with cert-manager wildcard TLS (`*.local.naguiar.dev` & `*.naguiar.dev`), **Pi-hole**, and **Tailscale**.

---

## Ideas Matrix

| Service | Category | Memory Target | Database / Backend | Persistence Tier | Blueprint File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Homepage** | Central Dashboard | ~60 – 100 MiB | None (ConfigMaps) | Longhorn (Config) | [`homepage.md`](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/ideas/homepage.md) |
| **Paperless-ngx** | Document Archiving / OCR | ~250 – 500 MiB | CloudNativePG + Valkey | Longhorn (Data) + NFS (Media/Consume) | [`paperless.md`](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/ideas/paperless.md) |
| **Linkwarden** | Bookmarks & Web Archiver | ~120 – 200 MiB | CloudNativePG | Longhorn (Assets) | [`linkwarden.md`](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/ideas/linkwarden.md) |
| **Stirling-PDF** | PDF Manipulation Toolkit | ~150 – 300 MiB | Stateless | Temporary / EmptyDir | [`stirling-pdf.md`](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/ideas/stirling-pdf.md) |
| **RomM & EmulatorJS** | Retro Gaming & In-Browser Play | ~150 MiB (Combined) | CloudNativePG / SQLite | Synology NFS (`secondary` ROMs) | [`romm-and-emulatorjs.md`](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/ideas/romm-and-emulatorjs.md) |
| **IT-Tools** | Sysadmin / Dev Utilities | ~15 – 25 MiB | Stateless | None | [`it-tools.md`](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/ideas/it-tools.md) |

---

## Suggested Application Indexing (`k8s/10_apps/`)

To preserve chronological and logical ordering across `k8s/10_apps`, the suggested sequence for rollout is:

* `k8s/10_apps/12_homepage`
* `k8s/10_apps/13_paperless`
* `k8s/10_apps/14_linkwarden`
* `k8s/10_apps/15_stirling-pdf`
* `k8s/10_apps/16_gaming` (RomM & EmulatorJS)
* `k8s/10_apps/17_it-tools`

---

## General Deployment Workflow (GitOps)

When you are ready to implement any idea:

1. **Create the App Directory Structure**:
   ```bash
   mkdir -p k8s/10_apps/<app_dir>/{values,secrets}
   ```
2. **If PostgreSQL is Required**:
   Add the new namespace to `reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces` and `reflection-auto-namespaces` in:
   [k8s/05_cluster-features/01_database/postgres-cluster/cluster.yaml](file:///home/naguiar/.gemini/antigravity-cli/worktrees/nlab/homeland_feature_ideas_brainstorm/k8s/05_cluster-features/01_database/postgres-cluster/cluster.yaml)
3. **Populate and Encrypt Secrets**:
   Copy the secret template from the corresponding markdown file, fill in strong credentials, and encrypt using SOPS:
   ```bash
   sops -e -i k8s/10_apps/<app_dir>/secrets/<app_name>.secrets.yaml
   ```
4. **Register in ArgoCD**:
   Add the application manifest to `k8s/05_cluster-features/05_argo-cd/applications/<app_name>.yaml` and reference it in `k8s/05_cluster-features/05_argo-cd/applications/kustomization.yaml`.
5. **Git Commit & Push**:
   Commit your changes to a feature branch, rebase on `origin/main`, push, and allow ArgoCD to sync.
   *(Never run `helmfile apply` directly!)*
