# Design Doc: Remove Argo CD Application Retries

Date: 2026-04-24
Topic: Remove `retry` block from Argo CD Application manifests.

## Problem
All Argo CD `Application` manifests in `k8s/05_cluster-features/05_argo-cd/applications/` currently have a `retry` policy configured with a limit of 1. The user wants to remove this retry configuration from all deployments in that folder.

## Proposed Change
Remove the `retry` block from the `syncPolicy` section in all YAML files within `k8s/05_cluster-features/05_argo-cd/applications/`.

### Targeted Block
```yaml
    retry:
      limit: 1
```

## Architecture & Components
- **Target Files:** `k8s/05_cluster-features/05_argo-cd/applications/*.yaml`
- **Tooling:** `sed` or `generalist` agent for bulk replacement.

## Success Criteria
- No YAML file in the specified directory contains the `retry:` key.
- The YAML structure remains valid after deletion.

## Testing Plan
- Run `grep -r "retry:" k8s/05_cluster-features/05_argo-cd/applications/` to confirm all instances are gone.
- Run `yamllint` or similar validation if available, or manually inspect 2-3 files.
