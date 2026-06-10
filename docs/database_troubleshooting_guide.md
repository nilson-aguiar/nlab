# CloudNativePG Database Cluster Troubleshooting & Recovery Guide

This guide documents the diagnosis, root causes, and recovery procedures for the CloudNativePG (CNPG) database cluster storage issues encountered on June 10, 2026. 

---

## 1. Incident Overview & Diagnosis

### Symptoms
* The PostgreSQL cluster phase shifts to `Not enough disk space`.
* The primary pod falls into a `CrashLoopBackOff` loop.
* Standby replica pods remain running but report `0/1` readiness (refusing connections).
* Interconnected applications (like `n8n`) fail to connect, returning `500` status codes.

### Diagnostic Commands

To inspect the cluster and identify disk issues, run the following:

```bash
# 1. Check the high-level status of the database cluster
kubectl get cluster -n cloudnative-pg

# 2. Check the logs of the crashing primary pod
kubectl logs <primary-pod-name> -n cloudnative-pg -c postgres --tail=100

# 3. Check physical PVC capacities
kubectl get pvc -n cloudnative-pg

# 4. Check actual disk space inside the postgres container of a running pod
kubectl exec <running-pod-name> -n cloudnative-pg -c postgres -- df -h
```

---

## 2. Root Cause Analysis

### Why the Disk Filled Up
1. **Replication Slot Blocks:** When a standby replica falls behind or gets stuck on an older timeline, the replication slot it uses on the primary remains **inactive** but **registered**.
2. **Infinite WAL Retention:** By default, PostgreSQL will retain Write-Ahead Logs (`pg_wal`) indefinitely to allow that lagging replica to catch up.
3. **The Crash:** If the write volume is high or a long period passes, these WAL files eventually fill up the entire PVC (100% capacity), forcing PostgreSQL to crash.
4. **The Deadlock:** Once the disk is 100% full, PostgreSQL cannot boot up to execute a checkpoint and delete the old `.done` WAL files. The CNPG operator safety block refuses to start PostgreSQL on any pod that reports insufficient space.

---

## 3. Recovery Procedure (Volume Expansion)

If the cluster is completely down due to a full disk, you must temporarily expand the volume size to allow PostgreSQL to boot up and run a checkpoint.

### Step 1: Temporarily Lower Longhorn Safety Threshold (If needed)
If host disks are near 75-80% capacity, Longhorn may reject expansion requests under its default 25% minimum free space rule. 
```bash
# Lower the threshold to 15% temporarily
kubectl patch setting storage-minimal-available-percentage -n longhorn-system --type=merge -p '{"value":"15"}'
```

### Step 2: Disable the CNPG Validating Webhook
Because the cluster is in a failed phase, the operator reconciler gets stuck in a loop and will not update the PVC specs. You must patch them manually, which requires temporarily disabling the validating webhook that blocks shrinking/altering storage values:
```bash
kubectl delete validatingwebhookconfiguration cnpg-validating-webhook-configuration
```

### Step 3: Patch the Cluster Spec and PVCs
Update the cluster spec and manually patch the PVCs to the new size (e.g. `100Gi`):
```bash
# Patch the cluster resource
kubectl patch cluster postgres -n cloudnative-pg --type=merge -p '{"spec":{"storage":{"size":"100Gi"}}}'

# Patch individual PVCs
kubectl patch pvc postgres-5 -n cloudnative-pg -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
kubectl patch pvc postgres-7 -n cloudnative-pg -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
kubectl patch pvc postgres-8 -n cloudnative-pg -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

### Step 4: Restart the Pods to Trigger Resize
Since filesystems must be unmounted/remounted to complete expansion under K8s/Longhorn, delete the pods to force them to recreate and mount the resized volumes:
```bash
kubectl delete pod postgres-5 postgres-7 postgres-8 -n cloudnative-pg
```
Once restarted:
* The volumes will resize to `100Gi`.
* The operator will lift the safety block.
* PostgreSQL will boot up, perform a checkpoint, and **automatically delete old WAL files**, dropping disk usage back down to <1GB.

### Step 5: Restore Safety Settings
```bash
# Restore Longhorn setting back to 25%
kubectl patch setting storage-minimal-available-percentage -n longhorn-system --type=merge -p '{"value":"25"}'
```

---

## 4. Rolling Shrink Procedure (Reclaiming Space)

Once the database is online and healthy, you can reclaim virtual scheduler space by performing a rolling shrink of your instances one-by-one back to a smaller size (e.g., `30Gi`):

1. **Update cluster.yaml:** Change `size: 100Gi` to `size: 30Gi`.
2. **Apply configurations:** Run `helmfile apply` (ensure the validation webhook is deleted/disabled if it blocks the apply, then proceed).
3. **Rebuild Standby Replicas:** Delete one standby replica pod and its PVC at a time. The operator will automatically recreate them at the new `30Gi` target size and sync data from the primary:
   ```bash
   # Rebuild replica A
   kubectl delete pod postgres-9 -n cloudnative-pg && kubectl delete pvc postgres-9 -n cloudnative-pg
   # (Wait for the new instance to be fully up and ready 1/1)
   
   # Rebuild replica B
   kubectl delete pod postgres-8 -n cloudnative-pg && kubectl delete pvc postgres-8 -n cloudnative-pg
   # (Wait for the new instance to be fully up and ready 1/1)
   ```
4. **Promote a Resized Instance:** Force a failover of the primary pod (`postgres-5` at `100Gi`) by deleting it:
   ```bash
   kubectl delete pod postgres-5 -n cloudnative-pg
   ```
   The operator will promote one of the healthy `30Gi` replicas to primary.
5. **Rebuild the Old Primary:** Once the failover completes, delete the old primary's PVC (`postgres-5`) to free the finalizer and let the operator recreate it at `30Gi`:
   ```bash
   kubectl delete pvc postgres-5 -n cloudnative-pg
   ```

---

## 5. Prevention Best Practices

To prevent replication slots from growing indefinitely and crashing the database again, configure the `max_slot_wal_keep_size` parameter in your `postgresql` block:

```yaml
spec:
  postgresql:
    parameters:
      max_slot_wal_keep_size: 5GB
```

This ensures that if a replica gets stuck on an old timeline or disconnects, the primary will drop the replication slot once WAL accumulation hits **5 GB**, protecting the database cluster from filling its disk.
