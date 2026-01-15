# Longhorn Storage (HA PVCs) on Skyforge k3s

Skyforge runs on a multi-node k3s cluster (`skyforge-1/2/3`). To avoid node-bound
storage (k3s `local-path`), we use Longhorn as the default storage class for
Skyforge PVCs.

## Install / Upgrade

From your workstation:

```bash
export KUBECONFIG=skyforge-private/.kubeconfig-skyforge
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm upgrade --install longhorn longhorn/longhorn -n longhorn-system --create-namespace -f deploy/longhorn-values.yaml --wait --timeout 10m
```

## Host prerequisites

On each k3s node:

- Ensure `open-iscsi` is installed and `iscsid` is running.
- Ensure the `iscsi_tcp` kernel module is loaded and persisted:
  - `/etc/modules-load.d/iscsi.conf` contains `iscsi_tcp`
- Ensure Longhorn data path exists on the big disk:
  - Bind mount `/var/lib/rancher/k3s/storage/longhorn` → `/var/lib/longhorn`

## Storage classes

- `longhorn` is the cluster default StorageClass.
- `local-path` is kept installed but is **not** default.

## Important: RWX vs RWO for Skyforge

Some Skyforge services intentionally share PVCs across multiple pods:

- `platform-data`: used by `healthwatch`, `skyforge-server`, `skyforge-server-worker`
- `skyforge-server-data`: used by `skyforge-server`, `skyforge-server-worker` (and LabPP jobs)

With k3s `local-path` (host directories), multiple pods could mount the same
volume on the same node.

With Longhorn, **RWO volumes are single-attach**, so shared volumes must be
provisioned as **RWX** (Longhorn share-manager) to avoid `Multi-Attach` errors.

The Skyforge chart sets:

- `platform-data` PVC: `ReadWriteMany`
- `skyforge-server-data` PVC: `ReadWriteMany`

## PVC sizing

The chart requests `5Gi` for most PVCs. This is intentional: `local-path` does
not enforce capacity, so historical data can exceed the old `100Mi` requests and
will break Longhorn migrations if not resized.

