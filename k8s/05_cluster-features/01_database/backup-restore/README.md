# CloudNativePG Cluster Troubleshooting Guide

This README documents how to troubleshoot and fix common issues with CloudNativePG PostgreSQL clusters, particularly when using Longhorn strict-local storage and VolumeSnapshot recovery.

## Common Issues Encountered

### Issue 1: Cluster Stuck in "Setting up primary" with No Pods Created

**Symptoms:**
- Cluster shows `STATUS: Setting up primary` but never progresses
- No pods are created for the cluster
- PVC shows status `cnpg.io/pvcStatus: initializing`

**Root Cause:**
Missing node affinity configuration when using Longhorn strict-local storage class.

### Issue 2: Pod Scheduling Failures with Strict-Local Storage

**Symptoms:**
- Pods fail to schedule with error: "persistentvolumeclaim not found"
- Events show: "0/3 nodes are available: pod has unbound immediate PersistentVolumeClaims"

**Root Cause:**
Longhorn strict-local storage requires pods to be scheduled on specific nodes where the data is stored, but the cluster lacks proper node affinity configuration.

### Issue 3: VolumeSnapshot Recovery with WAL Storage Incompatibility

**Symptoms:**
- Pod pending with error: `persistentvolumeclaim "postgres-1-wal" not found`
- Recovery from snapshot fails when cluster has separate walStorage configuration

**Root Cause:**
VolumeSnapshot only captures the main data volume, not the separate WAL volume, causing incompatibility during recovery.

## Diagnostic Commands

Use these commands to diagnose cluster issues:

```bash
# Check cluster status
kubectl get clusters.postgresql.cnpg.io -o wide

# Check pods status
kubectl get pods -n cloudnative-pg -l cnpg.io/cluster=<cluster-name> -o wide

# Check PVC status and annotations
kubectl describe pvc <pvc-name> -n cloudnative-pg
kubectl get pvc <pvc-name> -n cloudnative-pg -o jsonpath='{.metadata.annotations.cnpg\.io/pvcStatus}'

# Check PV node affinity
kubectl describe pv <pv-name>

# Check storage class configuration
kubectl describe storageclass longhorn-strict-local

# Check VolumeSnapshot availability
kubectl get volumesnapshots -o wide

# Check CloudNativePG operator logs
kubectl logs -n cloudnative-pg deployment/cloudnative-pg --tail=50

# Filter logs for specific cluster
kubectl logs -n cloudnative-pg deployment/cloudnative-pg --tail=100 | grep "cluster-name.*namespace"
```

## Solution Steps

### Step 1: Add Node Affinity for Strict-Local Storage

Add node affinity configuration to allow pods to be scheduled on any available node:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:16.4
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - homelab-0
            - homelab-1
            - homelab-2
  # ... rest of configuration
```

**Key Points:**
- Replace `homelab-0`, `homelab-1`, `homelab-2` with your actual node names
- Get node names with: `kubectl get nodes`
- This allows Kubernetes to schedule pods on any node where Longhorn can provision strict-local volumes

### Step 2: Fix PostgreSQL Image Version

Ensure you're using a valid PostgreSQL image version:

```yaml
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:16.4  # Use a known working version
```

**Common working versions:**
- `ghcr.io/cloudnative-pg/postgresql:16.4`
- `ghcr.io/cloudnative-pg/postgresql:16`
- `ghcr.io/cloudnative-pg/postgresql:15`

### Step 3: Handle VolumeSnapshot Recovery with WAL Storage

For snapshot recovery, temporarily remove separate WAL storage to avoid compatibility issues:

```yaml
spec:
  storage:
    size: 32Gi
    storageClass: longhorn-strict-local
  # Comment out walStorage during snapshot recovery
  # walStorage:
  #   storageClass: longhorn-strict-local
  #   size: 10Gi
  bootstrap:
    recovery:
      volumeSnapshots:
        storage:
          name: postgres-backup
          kind: VolumeSnapshot
          apiGroup: snapshot.storage.k8s.io
```

**Why this is needed:**
- VolumeSnapshots typically only capture the main data volume
- Separate WAL volumes are not included in the snapshot
- CloudNativePG expects both volumes during recovery, causing failures

### Step 4: Manually Mark PVC as Ready (If Needed)

If the cluster gets stuck waiting for PVC initialization:

```bash
# Check PVC status
kubectl get pvc postgres-1 -n cloudnative-pg -o jsonpath='{.metadata.annotations.cnpg\.io/pvcStatus}'

# If status is "initializing", manually mark as ready
kubectl annotate pvc postgres-1 -n cloudnative-pg cnpg.io/pvcStatus=ready --overwrite
```

**When to use this:**
- PVC is bound and provisioned successfully
- Longhorn volume is being restored from snapshot (slow process)
- CloudNativePG operator is stuck waiting for initialization

## Complete Working Configuration

Here's a complete working configuration for snapshot recovery with strict-local storage:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:16.4
  
  # Essential: Node affinity for strict-local storage
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - homelab-0  # Replace with your node names
            - homelab-1
            - homelab-2
  
  env:
    - name: TZ
      value: Europe/Amsterdam
  
  primaryUpdateStrategy: unsupervised
  primaryUpdateMethod: switchover
  
  storage:
    size: 32Gi
    storageClass: longhorn-strict-local
  
  # Removed walStorage for snapshot recovery compatibility
  # walStorage:
  #   storageClass: longhorn-strict-local
  #   size: 10Gi
  
  enableSuperuserAccess: true
  
  postgresql:
    parameters:
      max_connections: "400"
      shared_buffers: 256MB
  
  resources:
    requests:
      cpu: 500m
    limits:
      memory: 2Gi
  
  monitoring:
    enablePodMonitor: false
  
  # Bootstrap recovery from VolumeSnapshot
  bootstrap:
    recovery:
      volumeSnapshots:
        storage:
          name: postgres-backup
          kind: VolumeSnapshot
          apiGroup: snapshot.storage.k8s.io
```

## Deployment and Troubleshooting Process

### 1. Deploy the Cluster

```bash
# Apply your configuration
h apply  # or kubectl apply -f cluster.yaml
```

### 2. Monitor Progress

```bash
# Watch cluster status
watch kubectl get clusters.postgresql.cnpg.io postgres -o wide

# Watch pods
watch kubectl get pods -n cloudnative-pg -l cnpg.io/cluster=postgres -o wide
```

### 3. Troubleshoot Issues

**If cluster is stuck:**

```bash
# Check operator logs
kubectl logs -n cloudnative-pg deployment/cloudnative-pg --tail=20

# Check PVC status
kubectl describe pvc postgres-1 -n cloudnative-pg

# If PVC stuck in initializing, mark as ready
kubectl annotate pvc postgres-1 -n cloudnative-pg cnpg.io/pvcStatus=ready --overwrite
```

**If pods won't schedule:**

```bash
# Check pod events
kubectl describe pod <pod-name> -n cloudnative-pg

# Verify node affinity matches PV requirements
kubectl describe pv <pv-name>
```

### 4. Verify Success

A successful deployment should show:

```bash
kubectl get clusters.postgresql.cnpg.io postgres -o wide
# NAME       AGE     INSTANCES   READY   STATUS                PRIMARY
# postgres   5m      3           2       Waiting for instances postgres-1

kubectl get pods -n cloudnative-pg -l cnpg.io/cluster=postgres -o wide
# NAME         READY   STATUS    NODE
# postgres-1   1/1     Running   homelab-0
# postgres-2   1/1     Running   homelab-1
# postgres-3   0/1     Running   homelab-2
```

## Key Lessons Learned

1. **Node Affinity is Critical**: With Longhorn strict-local storage, always configure node affinity to match your cluster topology.

2. **VolumeSnapshot Limitations**: Separate WAL storage can cause issues during snapshot recovery. Consider using single-volume configuration for recovery scenarios.

3. **PVC Initialization Timing**: Longhorn volume restoration from snapshots can be slow. The manual PVC ready annotation is a useful workaround.

4. **Image Version Validation**: Always verify PostgreSQL image versions are available in the registry before deployment.

5. **Operator Logs are Essential**: CloudNativePG operator logs provide crucial debugging information for troubleshooting cluster issues.

## Future Considerations

### Re-enabling WAL Storage

After successful recovery, you can re-enable separate WAL storage:

```bash
# Edit the cluster
kubectl edit cluster postgres -n cloudnative-pg

# Add back walStorage configuration
spec:
  walStorage:
    storageClass: longhorn-strict-local
    size: 10Gi
```

### Creating New Snapshots

For future backups, create snapshots of both volumes:

```bash
# Create data volume snapshot
kubectl create volumesnapshot postgres-data-backup --source-pvc=postgres-1

# Create WAL volume snapshot (if using separate WAL storage)
kubectl create volumesnapshot postgres-wal-backup --source-pvc=postgres-1-wal
```

## Additional Resources

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [Longhorn Storage Classes](https://longhorn.io/docs/latest/references/storage-class-parameters/)
- [Kubernetes Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity)
- [VolumeSnapshot Recovery](https://cloudnative-pg.io/documentation/current/bootstrap/#bootstrap-from-a-volume-snapshot)
