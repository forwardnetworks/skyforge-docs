# Longhorn Storage (HA PVCs) on Skyforge k3s

Skyforge runs on a multi-node k3s cluster (`skyforge-1/2/3`). To avoid node-bound
storage (k3s `local-path`), we use Longhorn as the default storage class for
Skyforge PVCs.

## Install / Upgrade

From your workstation:

```bash
export KUBECONFIG=skyforge/.kubeconfig-skyforge
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm upgrade --install longhorn longhorn/longhorn -n longhorn-system --create-namespace -f deploy/longhorn-values.yaml --wait --timeout 10m
```

## Host prerequisites

On each k3s node:

- Ensure `open-iscsi` is installed and `iscsid` is running.
- Ensure the `iscsi_tcp` kernel module is loaded and persisted:
  - `/etc/modules-load.d/iscsi.conf` contains `iscsi_tcp`
- Ensure the big disk backs both Longhorn replicas and Forward's node-agent
  data path:
  - Bind mount `/var/lib/rancher/k3s/storage/longhorn` -> `/var/lib/longhorn`
  - Bind mount a directory on the same big disk -> `/mnt/forward/extended`
  - Do not leave `/mnt/forward/extended` on the root filesystem. Forward's
    `node-agent` reports that path as the `DATA` disk, and the platform enters
    read-only mode when that path runs low on space even if Longhorn itself is
    healthy on a different device.

## Storage classes

- `longhorn` is the cluster default StorageClass.
- `local-path` is kept installed but is **not** default.

## Important: RWX vs RWO for Skyforge

Some Skyforge services intentionally share PVCs across multiple pods:

- `platform-data`: used by `healthwatch`, `skyforge-server`, `skyforge-server-worker`
- `skyforge-server-data`: used by `skyforge-server` and `skyforge-server-worker`

With k3s `local-path` (host directories), multiple pods could mount the same
volume on the same node.

With Longhorn, **RWO volumes are single-attach**, so shared volumes must be
provisioned as **RWX** (Longhorn share-manager) to avoid `Multi-Attach` errors.

The Skyforge chart sets:

- `platform-data` PVC: `ReadWriteMany`
- `skyforge-server-data` PVC: `ReadWriteMany`

Forward in-cluster storage currently includes PVC-backed workloads that are
`ReadWriteOnce`. For this model, we enforce a rollout policy instead of hard
node pinning:

- PVC-backed Forward **Deployments** are forced to `strategy.type=Recreate`
  during deploy and reboot recovery.
- PVC-backed Forward Deployments with `replicas > 1` are rejected by deploy
  policy.
- Forward shared scratch is hard-cut to `forward-scratch` (`ReadWriteOnce`).
- Deploy/recovery scripts normalize legacy `*-rwx` claim references back to
  `forward-scratch`, `forward-cbr-backups`, and `forward-cbr-restore`.
- `scripts/bootstrap-forward-local.sh` creates those contract PVCs directly when
  the upstream Forward chart does not render them.
- Forward spread/anti-affinity policy is always applied across
  Deployments/StatefulSets with `whenUnsatisfiable=DoNotSchedule`
  (no toggle/fallback path).

This avoids attach churn from concurrent replacement pods while still allowing
the scheduler to place workloads across nodes.

## Bootstrap verification

`scripts/bootstrap-forward-local.sh` now validates the big-disk contract when
the Forward chart is configured for `longhorn` storage:

- Longhorn's `default-data-path` must be `/var/lib/longhorn`
- each schedulable Longhorn disk must meet the expected capacity floor
  (`SKYFORGE_FORWARD_LONGHORN_MIN_GIB`, default `750`)
- after Forward deploys, `fwd-node-agent` must also see `/mnt/forward/extended`
  on a filesystem at or above that same capacity floor

If any of those checks fail, bootstrap exits with a concrete error instead of
letting Forward drift into false low-space or read-only mode later.

## PVC sizing

The chart requests `5Gi` for most PVCs. This is intentional: `local-path` does
not enforce capacity, so historical data can exceed the old `100Mi` requests and
will break Longhorn migrations if not resized.
