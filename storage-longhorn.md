# Longhorn Storage (HA PVCs) on Skyforge k3s

Skyforge should use Longhorn as the storage backend for all critical PVC-backed
services. `local-path` stays installed only for disposable or intentionally
node-local claims.

## Install / Upgrade

From your workstation:

```bash
export KUBECONFIG=skyforge/.kubeconfig-skyforge
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm upgrade --install longhorn longhorn/longhorn \
  -n longhorn-system --create-namespace \
  -f deploy/longhorn-values.yaml \
  -f deploy/longhorn-values-qa.yaml \
  --wait --timeout 10m
```

These values include:

- `defaultSettings.taintToleration: node-role.kubernetes.io/control-plane:NoSchedule`
- `defaultSettings.defaultReplicaCount: 3`
- `defaultSettings.autoSalvage: true`
- `defaultSettings.autoDeletePodWhenVolumeDetachedUnexpectedly: true`
- `defaultSettings.disableSchedulingOnCordonedNode: true`
- `defaultSettings.nodeDrainPolicy: block-if-contains-last-replica`
- `defaultSettings.nodeDownPodDeletionPolicy: delete-both-statefulset-and-deployment-pod`

That keeps Longhorn CSI components schedulable on control-plane nodes so
control-plane-pinned Skyforge pods can still mount PVCs.

The node-down policy is important for reboot resilience: when a worker dies or
stays down long enough to be treated as unavailable, Longhorn should allow the
controller to delete the old pod and reattach the RWO volume on a healthy node
instead of waiting indefinitely on the dead node.

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

- `longhorn` should become the cluster default StorageClass after migration.
- `local-path` stays installed but is **not** default.

## Important: Skyforge server PVC contract

The current Skyforge runtime does **not** use shared RWX PVCs for the API
server and workers.

- `platform-data`: mounted by `skyforge-server`
- `skyforge-server-data`: mounted by `skyforge-server`
- `skyforge-server-worker` uses ephemeral `emptyDir` volumes for its local
  working paths instead of mounting those server PVCs

With Longhorn, these server-side PVCs should remain **RWO**:

- `platform-data` PVC: `ReadWriteOnce`
- `skyforge-server-data` PVC: `ReadWriteOnce`

If Skyforge later moves back to a truly shared multi-pod storage contract for
these paths, that should be implemented explicitly and then migrated to RWX in
both chart values and the live PVCs together.

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

## Backup contract during migration

Do not treat Longhorn replication as sufficient backup.

Keep these enabled throughout the migration window:

- `skyforge.backups.localSpread`
- `skyforge.backups.offsiteRaw`
- `skyforge.backups.forwardRaw`
- `skyforge.backups.postgres`

`backup-offsite-raw` should run as a DaemonSet so every eligible node mirrors
its local backup root off-cluster, not just whichever node a CronJob lands on.

## PVC sizing

The chart requests `5Gi` for most PVCs. This is intentional: `local-path` does
not enforce capacity, so historical data can exceed the old `100Mi` requests and
will break Longhorn migrations if not resized.
