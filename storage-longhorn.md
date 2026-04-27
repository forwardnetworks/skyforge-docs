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

The default checked-in values are for the supported local single-node profile.
They include:

- `defaultSettings.taintToleration: node-role.kubernetes.io/control-plane:NoSchedule`
- `defaultSettings.defaultDataPath: /data/skyforge/longhorn`
- `defaultSettings.defaultReplicaCount: 1`
- `defaultSettings.concurrentReplicaRebuildPerNodeLimit: 1`
- `defaultSettings.autoSalvage: true`
- `defaultSettings.autoDeletePodWhenVolumeDetachedUnexpectedly: true`
- `defaultSettings.disableSchedulingOnCordonedNode: true`
- `defaultSettings.nodeDrainPolicy: block-if-contains-last-replica`
- `defaultSettings.nodeDownPodDeletionPolicy: delete-both-statefulset-and-deployment-pod`

That keeps Longhorn CSI components schedulable on the single k3s
control-plane/workload node so Skyforge pods can still mount PVCs.

Do not use the single-node values as an HA storage contract. Before returning
to a multi-node Longhorn layout, add an explicit HA overlay that sets
`defaultReplicaCount: 3`, chooses the intended data path, and validates replica
placement across the schedulable storage nodes.

The node-down policy is important for reboot resilience: when a worker dies or
stays down long enough to be treated as unavailable, Longhorn should allow the
controller to delete the old pod and reattach the RWO volume on a healthy node
instead of waiting indefinitely on the dead node.

The rebuild concurrency limit is intentionally conservative. Skyforge app nodes
can run Forward, lab devices, collectors, and Longhorn replicas at the same
time; limiting rebuilds to one per node avoids recovery storms that compete with
active workloads and trigger probe/API latency.

## Host prerequisites

On each k3s node:

- Ensure `open-iscsi` is installed and `iscsid` is running.
- Ensure the `iscsi_tcp` kernel module is loaded and persisted:
  - `/etc/modules-load.d/iscsi.conf` contains `iscsi_tcp`
- Ensure the big disk backs both Longhorn replicas and Forward's node-agent
  data path:
  - Use `/data/skyforge/longhorn` as the Longhorn data path for the local
    single-node profile.
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
- Deploy/recovery scripts still normalize a few legacy `*-rwx` claim names
  during migration windows. The supported native Forward profile removes the
  built-in collector but keeps the CBR server, internal CBR agent, and CBR S3
  agent because Forward 26.4 snapshot upload and backup/restore paths depend on
  them.
- `scripts/deploy-skyforge-env.sh qa` creates those contract PVCs directly when
  the upstream Forward chart does not render them.
- Forward spread/anti-affinity policy is always applied across
  Deployments/StatefulSets with `whenUnsatisfiable=DoNotSchedule`
  (no toggle/fallback path).

This avoids attach churn from concurrent replacement pods while still allowing
the scheduler to place workloads across nodes.

## Bootstrap verification

`scripts/deploy-skyforge-env.sh qa` now validates the big-disk contract when
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

The supported production contract is:

- `skyforge.backups.forward.engine=longhorn`
- `skyforge.backups.forward.bucket=forward-platform-backups`
- `skyforge.backups.forward.targetNamespace=longhorn-system`
- `skyforge.backups.postgres`
- `skyforge.forwardCluster.core.cbr.s3Backup.enabled=true` points Forward CBR at
  in-cluster `s3gw` using the same `forward-platform-backups` bucket; secret
  material is synced from the existing Skyforge object-storage credentials into
  `forward/fwd-s3-backup-settings`.

Use these only as legacy adjuncts when migrating older node-local storage:

- `skyforge.backups.localSpread`
- `skyforge.backups.offsiteRaw`
- `skyforge.backups.forwardRaw`

## PVC sizing

The chart requests `5Gi` for most PVCs. This is intentional: `local-path` does
not enforce capacity, so historical data can exceed the old `100Mi` requests and
will break Longhorn migrations if not resized.
