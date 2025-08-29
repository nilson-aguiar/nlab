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

## Repository Structure

The repository is organized into two main directories: `nixos` and `k8s`.

### `/nixos`

This directory contains all the NixOS configurations for the cluster nodes.

*   It uses Nix Flakes to define the system configuration for each host (e.g., `homelab-0`, `homelab-1`).
*   These configurations handle everything from user accounts and SSH keys to the installation and configuration of the k3s agent or server on each node.

### `/k8s`

This directory holds all the Kubernetes application configurations, managed by Helmfile. The subdirectories are numbered to imply a logical deployment order.

*   **`helmfile.yaml`**: Each application or component has its own `helmfile.yaml`, which defines the Helm chart to use, the release name, namespace, and paths to value files.
*   **`values/`**: Contains `values.yaml` files that override the default Helm chart values.
*   **`secrets/`**: Contains SOPS-encrypted values files (e.g., `n8n.values.secrets.yaml`). These are referenced in the `helmfile.yaml` and automatically decrypted during deployment.

#### Key `k8s` Directories:

*   **`01_setup`**: Foundational cluster components, like `kube-vip` for creating a load balancer for the Kubernetes API.
*   **`03_ingress-dns`**: Networking services. This includes `traefik` as the ingress controller and `pihole` for internal DNS resolution.
*   **`04_monitoring`**: The observability stack. It includes an `opentelemetry-collector` to receive and process traces and metrics from applications.
*   **`05_cluster-features`**: Core, cluster-wide services like `argo-cd` for GitOps, `influxdb` for data storage, and `smarter-device-manager` for exposing host devices (like USB devices) to pods.
*   **`10_apps`**: User-facing applications, such as:
    *   `n8n`: A workflow automation tool.
    *   `stash`: A custom application using `yt-dlp` to download videos via a CronJob.
    *   `openwebui`: A web UI for interacting with local AI models via Ollama.

## Workflow Summary

1.  **Node Provisioning**: A new machine is set up by installing NixOS and applying a configuration from the `/nixos` directory.
2.  **Application Deployment**: From a management machine with `helmfile` installed, running `helmfile apply` within a specific directory inside `/k8s` will deploy or update the corresponding application in the cluster. Helmfile handles the decryption of secrets and the rendering of Helm templates.
