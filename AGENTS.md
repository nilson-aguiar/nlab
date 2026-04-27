# Gemini Code Assist - Repository Context

This document provides context for the Gemini Code Assist model to understand the structure and purpose of this repository.

## Project Overview

This repository contains the complete configuration for a personal homelab environment. The primary goal is to manage a Kubernetes cluster and the applications running on it in a declarative, GitOps-friendly manner.

The infrastructure is built on physical or virtual machines running NixOS, which are then configured to form a Kubernetes cluster. Applications are deployed onto the cluster using Helm and Helmfile.

## Core Technologies

*   **Operating System & Provisioning**: **NixOS** is used to declaratively configure the operating system for each node in the cluster. This includes package management, networking, and the Kubernetes (k3s) installation itself.
*   **Container Orchestration**: **Kubernetes** (specifically k3s) is the container orchestrator for running all applications.
*   **Application Deployment**: **Helm** is the package manager for Kubernetes. **Helmfile** is used as a declarative wrapper around Helm to manage releases, their values, and secrets in a structured way.
*   **Secrets Management**: **SOPS** (Secrets OPerationS) is used to encrypt and decrypt secrets, primarily Helm values files. The encryption method used is **age**. Encrypted files are committed directly to the repository and decrypted at deploy time by Helmfile.
*   **GitOps**: **ArgoCD** is used for continuous delivery, ensuring the cluster state matches the repository.

## Repository Structure

The repository is organized into two main directories: `nixos` and `k8s`.

### `/nixos`

This directory contains all the NixOS configurations for the cluster nodes.

*   It uses Nix Flakes to define the system configuration for each host (e.g., `homelab-0`, `homelab-1`, `homelab-2`).
*   **`flake.nix`**: Entry point for the Nix configuration.
*   **`configuration.nix`**: Core system settings, including k3s server/agent setup, user accounts, and kernel modules.
*   **`disko-config.nix`**: Declarative disk partitioning using Disko.
*   **`secrets/`**: Contains `secrets.yaml` managed by `sops-nix` for system-level secrets (e.g., k3s tokens).

### `/k8s`

This directory holds all the Kubernetes application configurations, managed by Helmfile. The subdirectories are numbered to imply a logical deployment order.

*   **`01_setup`**: Foundational components (networking, metallb, cert-manager).
*   **`02_storage`**: Persistent storage (NFS, Longhorn, Volume Snapshots).
*   **`03_ingress-dns`**: Ingress (Traefik) and internal DNS (Pi-hole).
*   **`04_monitoring`**: Observability stack (VictoriaMetrics, Telemetry).
*   **`05_cluster-features`**: Shared services (PostgreSQL, ArgoCD, Cloudflare Tunnel).
*   **`10_apps`**: User-facing applications (Home Assistant, n8n, Stash, etc.).

Each application directory typically contains:
*   **`helmfile.yaml`**: Defines the Helm release.
*   **`values/`**: Standard Helm values.
*   **`secrets/`**: SOPS-encrypted values (e.g., `*.values.secret.yaml`).

## Key Commands

### NixOS Management

- **Update/Rebuild Node**:
  ```bash
  sudo nixos-rebuild switch --upgrade --refresh --flake github:nilson-aguiar/nlab?dir=nixos
  ```
- **Provision New Node** (via `nixos-anywhere`):
  ```bash
  nix run github:nix-community/nixos-anywhere -- --flake '.#homelab-0' nixos@<IP> --build-on-remote
  ```

### Kubernetes Management (Helmfile)

- **Deploy specific app**:
  Navigate to the app directory (e.g., `k8s/10_apps/01_home-assistant`) and run:
  ```bash
  helmfile apply
  ```
- **Apply all configurations**:
  ```bash
  ./k8s/update-all.sh
  ```
- **Check differences**:
  ```bash
  ./k8s/diff-all.sh
  ```

### Secrets Management

- **Edit encrypted secrets**:
  ```bash
  sops k8s/10_apps/<app>/secrets/<filename>.values.secret.yaml
  ```

## Development Conventions

1.  **Surgical Updates**: When modifying application configurations, always check if there is a corresponding `secrets/` file that might need updates alongside `values/`.
2.  **ArgoCD Registration**: New applications added to `k8s/10_apps` must have a corresponding manifest in `k8s/05_cluster-features/05_argo-cd/applications/` to be managed via GitOps.
3.  **Namespace Consistency**: Ensure the `namespace` in `helmfile.yaml` matches the intended deployment target.
4.  **Standardized Deployments (bjw-s)**: For general applications, prefer using the `bjw-s/app-template` (OCI: `ghcr.io/bjw-s-labs/helm`).
    *   **Secrets Pattern**: Structure sensitive data within `secrets` blocks to leverage the app-template's native secret generation:
        ```yaml
        secrets:
          app-secret:
            enabled: true
            stringData:
              VARIABLE_NAME: "value"
        ```
    *   **Encryption**: Encrypt secret files using `helm secrets encrypt -i <file>` before committing.
5.  **Service Discovery**: When linking applications across namespaces, use the full internal DNS pattern: `<release>-<service>.<namespace>.svc.cluster.local:<port>`.
6.  **NixOS State Version**: Do not change `system.stateVersion` in `configuration.nix` as it is tied to the initial installation.
7.  **SOPS Keys**: System secrets require the age key at `~/.config/sops/age/keys.txt`.

## Workflow Summary

1.  **Node Provisioning**: A new machine is set up by installing NixOS and applying a configuration from the `/nixos` directory.
2.  **Application Deployment**: From a management machine with `helmfile` installed, running `helmfile apply` within a specific directory inside `/k8s` will deploy or update the corresponding application in the cluster. Helmfile handles the decryption of secrets and the rendering of Helm templates.
3.  **GitOps Registration**: Application manifests in `k8s/05_cluster-features/05_argo-cd/applications/` ensure the application is automatically managed and synced by ArgoCD.
