# ArgoCD Applications

This directory contains ArgoCD Application manifests for managing deployments.

## media-flix

The `media-flix.yaml` Application manages all media-related services (prowlarr, sonarr, radarr, etc.) using Helmfile.

### Setup Requirements

1. **Update the Git repository URL** in `media-flix.yaml`:
   - Change `repoURL` to your actual repository URL
   - Verify `targetRevision` matches your default branch

2. **Deploy ArgoCD with Helmfile plugin**:
   ```bash
   cd k8s/05_cluster-features/05_argo-cd
   helmfile apply
   ```

3. **Verify the deployment**:
   ```bash
   kubectl get application -n argocd media-flix
   kubectl get pods -n media-flix
   ```

### How it works

- ArgoCD uses a Helmfile plugin (sidecar container) to render the media-flix Helmfile
- The plugin automatically decrypts SOPS-encrypted secrets using the age key from the node
- Age key is mounted from the host at `/home/naguiar/.config/sops/age/keys.txt`
- All 9 media-flix releases are managed as a single Application

### Sync Policy

The Application is configured with:
- **Automated sync**: Changes in Git trigger automatic deployments
- **Self-heal**: ArgoCD will revert manual changes to match Git state
- **Prune**: Resources removed from Git will be deleted from the cluster
