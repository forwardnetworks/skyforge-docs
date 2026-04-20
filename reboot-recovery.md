# Prod Reboot Recovery

Use this after node/kernel reboots when services do not fully recover on their own.

## Why this exists

Cold-start timing can cause transient failures in three areas:

- Cilium/Multus datapath readiness per node.
- Forward worker cold-start before probe budget is exhausted.
- Infoblox VM/lifecycle lanes returning in suspended or halted states.
- Forward node-role drift after node re-registration if master/worker labels are
  not reconciled declaratively.

## Forward role contract

When `skyforge.forwardCluster.nodeRoleReconciler.enabled=true`, Skyforge
installs a Helm-managed reconciler that continuously enforces the intended
Forward node-role labels from chart values:

- `node-role.kubernetes.io/fwd-master`
- `node-role.kubernetes.io/fwd-monitoring`
- `node-role.kubernetes.io/fwd-compute-worker`
- `node-role.kubernetes.io/fwd-search-worker`
- `forwardnetworks.com/role=forward`
- `forwardnetworks.com/scratch-group=forward-scratch`

This prevents the specific failure mode where a recreated node object loses its
labels, Forward master pods become unschedulable, and the Forward route drops
because `fwd-appserver` has no endpoints.

For the production profile in `deploy/skyforge-values.yaml`,
the `master` role should not be pinned to a single worker. Keep at least two
healthy worker nodes in `skyforge.forwardCluster.nodeRoleReconciler.nodeRoles.master`.

When Forward is still on `local-path`, that set must include every node that
owns critical Forward PVs. After migration to Longhorn, the recovery contract
changes: the reboot path should validate Longhorn-backed PVC health instead of
trying to preserve local-path node ownership.

Production deploy guard:
- `scripts/deploy-skyforge-prod-safe.sh` enforces this at rollout time and fails
  when fewer than two `fwd-master` nodes are `Ready` and schedulable.

## One-command recovery

Run from repo root:

```bash
./scripts/recover-prod-after-reboot.sh
```

Defaults:

- `NAMESPACE=skyforge`
- `FORWARD_NAMESPACE=forward`
- `STRICT_MODE=true`

Optional:

```bash
STRICT_MODE=false ./scripts/recover-prod-after-reboot.sh
```

## What the script does

1. Validates all nodes are `Ready`.
2. Runs `scripts/k8s-network-resilience.sh` with repair enabled.
3. Applies Forward worker probe hardening for cold-start:
   - adds `startupProbe` on compute/search worker service ports
   - raises liveness `initialDelaySeconds` to `300` if lower
4. Enforces Forward DB auth single-source-of-truth from Kubernetes secrets (`scripts/lib/forward-db-auth.sh::forward_enforce_pg_secret_source_of_truth`):
   - reconciles Postgres role passwords from `postgres.fwd-pg-*.credentials`
   - requires both `username` and `user` keys to match expected role
   - validates service-level DB login via `fwd-pg-app`, `fwd-pg-fdb-0`, and `fwd-pg-fdb-1`
   - fails closed on any mismatch
5. Temporarily halts Infoblox VM during Forward recovery to avoid cold-start memory contention.
6. Restarts critical Forward and Skyforge workloads in deterministic order.
7. Unsuspends Infoblox lifecycle cronjobs and sets VM `runStrategy=Always` when present.
8. Waits for rollout completion and fails if unhealthy pods remain (strict mode).
9. Validates the Forward storage contract against the live storage mode:
   - `local-path`: critical PVCs remain pinned to eligible `fwd-master` nodes
   - `longhorn`: critical PVCs are Bound on `storageClassName=longhorn`
10. Assumes the Longhorn reboot contract from `deploy/longhorn-values.yaml` is
    in force:
   - `defaultReplicaCount=3`
   - `autoSalvage=true`
   - `autoDeletePodWhenVolumeDetachedUnexpectedly=true`
   - `disableSchedulingOnCordonedNode=true`
   - `nodeDrainPolicy=block-if-contains-last-replica`
   - `nodeDownPodDeletionPolicy=delete-both-statefulset-and-deployment-pod`

Toggle this behavior with:

```bash
PAUSE_INFOBLOX_DURING_FORWARD_RECOVERY=false ./scripts/recover-prod-after-reboot.sh
```

Run the DB auth guard independently without a full recovery:

```bash
FORWARD_NAMESPACE=forward ./scripts/forward-db-auth-guard.sh
```

## Contract

- This is a recovery path, not a replacement for normal deploy.
- Keep probe and restart logic in this script deterministic and idempotent.
- Any additional reboot failure mode should be added here with explicit checks.

## Forward scratch volume recovery

If Forward core or workers come back with logs like `Read-only file system` on
`/var/log/forward` or `/tmp`, or a critical Forward pod becomes unschedulable
after a reboot, treat it as a storage-contract failure rather than an app
configuration issue.

Recovery steps:

1. Confirm the affected pod is failing on writable paths such as
   `/var/log/forward` or `/tmp`.
2. Confirm the PVC storage mode:
   - `local-path`: confirm which node owns the corresponding PV and whether
     that node is still labeled as an eligible `fwd-master`
   - `longhorn`: confirm the PVC is Bound, the Longhorn volume is healthy, and
     the workload can reattach on another healthy worker
3. If the node label drifted in a `local-path` deployment, restore the Forward
   node-role labels and let the pod reschedule there.
4. If the storage backend itself is unhealthy, recover from backup rather than
   patching around the mounts.

Do not patch around this by making the Forward containers writable on rootfs or
by bypassing the scratch PVC mounts. In this storage model, the correct fix is
to recover the storage contract and keep the stateful `fwd-master` set aligned
with the actual Forward PVC backend in use.
