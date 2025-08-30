#!/bin/bash
set -e

# A script to migrate Longhorn PVCs used by a deployment from ReadWriteMany to ReadWriteOnce
# by using the Kubernetes-native VolumeSnapshot method.

# --- Configuration ---
# The name of your VolumeSnapshotClass. '''longhorn''' is the default.
VOLUME_SNAPSHOT_CLASS="longhorn-snapshot-vsc"

# --- Usage ---
usage() {
  echo "Usage: $0 -n <NAMESPACE> -d <DEPLOYMENT_NAME>"
  echo "  -n NAMESPACE:         The Kubernetes namespace where the deployment exists."
  echo "  -d DEPLOYMENT_NAME:   The name of the deployment whose PVCs you want to migrate."
  exit 1
}

# --- Argument Parsing ---
NAMESPACE=""
DEPLOYMENT_NAME=""
while getopts ":n:d:" opt; do
  case ${opt} in
    n ) NAMESPACE=$OPTARG ;; d ) DEPLOYMENT_NAME=$OPTARG ;; \? ) echo "Invalid option: -$OPTARG" 1>&2; usage ;; : ) echo "Invalid option: -$OPTARG requires an argument" 1>&2; usage ;; esac
done

if [ -z "$NAMESPACE" ] || [ -z "$DEPLOYMENT_NAME" ]; then
    echo "Error: All arguments (-n, -d) are required."
    usage
fi

echo "# --- Step 1: Discover PVCs from Deployment ---"
echo "--> Discovering PVCs used by deployment '''${DEPLOYMENT_NAME}'''..."
PVC_NAMES=($(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}'))

if [ ${#PVC_NAMES[@]} -eq 0 ]; then
  echo "Error: No PVCs found in deployment '''${DEPLOYMENT_NAME}'''. Nothing to do."
  exit 0
fi

echo "--> Found PVCs: ${PVC_NAMES[*]}"

echo "# --- Step 2: Get PVC info and Create Snapshots ---"

SNAPSHOT_NAMES=()
LONGHORN_PVC_NAMES=()
PVC_STORAGE_CLASSES=()
PVC_STORAGE_SIZES=()
for pvc_name in "${PVC_NAMES[@]}"; do
  echo "--> Getting info for PVC '''${pvc_name}'''"
  if ! pvc_json=$(kubectl get pvc "${pvc_name}" -n "${NAMESPACE}" -o json 2>/dev/null); then
    echo "Warning: PVC '''${pvc_name}''' not found. Skipping."
    continue
  fi

  storage_class=$(echo "$pvc_json" | jq -r '.spec.storageClassName')

  if [[ "${storage_class}" != "longhorn" ]]; then
    echo "--> PVC '''${pvc_name}''' is not a longhorn volume (storage class is '''${storage_class}'''). Skipping."
    continue
  fi

  LONGHORN_PVC_NAMES+=("${pvc_name}")
  storage_size=$(echo "$pvc_json" | jq -r '.spec.resources.requests.storage')
  PVC_STORAGE_CLASSES+=("${storage_class}")
  PVC_STORAGE_SIZES+=("${storage_size}")

  snapshot_name="${pvc_name}-migration"
  SNAPSHOT_NAMES+=("${snapshot_name}")

  if kubectl get volumesnapshot "${snapshot_name}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "--> VolumeSnapshot '''${snapshot_name}''' already exists. Skipping creation."
  else
    echo "--> VolumeSnapshot '''${snapshot_name}''' does not exist. Checking if deployment is running..."
    ready_replicas=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}')

    if [[ -z "${ready_replicas}" || "${ready_replicas}" -lt 1 ]]; then
      echo "Warning: Deployment '''${DEPLOYMENT_NAME}''' has no ready replicas. The volume must be attached to create a snapshot."
      read -p "Do you want to scale the deployment to 1 replica to proceed? (y/N) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "--> Scaling deployment '''${DEPLOYMENT_NAME}''' to 1 replica..."
        kubectl scale deployment "${DEPLOYMENT_NAME}" --replicas=1 -n "${NAMESPACE}"
        echo "--> Waiting for deployment to become available..."
        kubectl wait --for=condition=Available --timeout=300s deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"
      else
        echo "Aborting. Cannot create snapshot for '''${pvc_name}''' without a running pod."
        exit 1
      fi
    fi

    echo "--> Will create VolumeSnapshot '''${snapshot_name}''' for PVC '''${pvc_name}'''."
    read -p "Press [Enter] to continue..."
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: ${snapshot_name}
  namespace: ${NAMESPACE}
spec:
  volumeSnapshotClassName: ${VOLUME_SNAPSHOT_CLASS}
  source:
    persistentVolumeClaimName: ${pvc_name}
EOF
  fi
done

if [ ${#LONGHORN_PVC_NAMES[@]} -eq 0 ]; then
  echo "No Longhorn PVCs found to migrate. Exiting."
  exit 0
fi

echo "# --- Step 3: Wait for Snapshots to be Ready ---"
read -p "Press [Enter] to continue..."
echo "--> Waiting for all snapshots to be ready to use..."
for snapshot_name in "${SNAPSHOT_NAMES[@]}"; do
  while [[ "$(kubectl get volumesnapshot "${snapshot_name}" -n "${NAMESPACE}" -o jsonpath='{.status.readyToUse}')" != "true" ]]; do
    echo "  Waiting for snapshot '''${snapshot_name}''' to be ready..."
    sleep 5
  done
  echo "  Snapshot '''${snapshot_name}''' is ready."
done

echo "# --- Step 4: Scale Down Deployment ---"
echo "--> This will scale down deployment '''${DEPLOYMENT_NAME}''' to 0 replicas."
read -p "Press [Enter] to continue..."
kubectl scale deployment "${DEPLOYMENT_NAME}" --replicas=0 -n "${NAMESPACE}"

echo "# --- Step 5: Delete Original PVCs ---"
if [ ${#LONGHORN_PVC_NAMES[@]} -gt 0 ]; then
    echo "--> The following PVCs will be DELETED: ${LONGHORN_PVC_NAMES[*]}"
    read -p "Press [Enter] to continue..."
    kubectl delete pvc "${LONGHORN_PVC_NAMES[@]}" -n "${NAMESPACE}" --ignore-not-found=true
else
    echo "--> No PVCs to delete."
fi

echo "# --- Step 6: Create New PVCs from Snapshots ---"
echo "--> Re-creating PVCs with ReadWriteOnce from snapshots..."
for i in "${!LONGHORN_PVC_NAMES[@]}"; do
  pvc_name="${LONGHORN_PVC_NAMES[i]}"
  storage_class="${PVC_STORAGE_CLASSES[i]}"
  storage_size="${PVC_STORAGE_SIZES[i]}"
  snapshot_name="${pvc_name}-migration"

  echo "  --> Will create new PVC '''${pvc_name}''' from snapshot '''${snapshot_name}'''"
  read -p "Press [Enter] to continue..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${pvc_name}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${storage_size}
  dataSource:
    name: ${snapshot_name}
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
EOF
done

# --- Step 7: Apply Helmfile ---
#echo "--> Applying Helmfile to adopt new PVCs and scale up deployment..."
#helmfile apply

echo "# --- Step 7: Cleanup Snapshots ---"
if [ ${#SNAPSHOT_NAMES[@]} -gt 0 ]; then
    echo "--> The following migration snapshots will be DELETED: ${SNAPSHOT_NAMES[*]}"
    read -p "Press [Enter] to continue..."
    kubectl delete volumesnapshot "${SNAPSHOT_NAMES[@]}" -n "${NAMESPACE}"
else
    echo "--> No snapshots to clean up."
fi

echo "### Migration Complete! Don't forget to update your helmfile"
