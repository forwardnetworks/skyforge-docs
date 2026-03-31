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

For the production profile in `components/charts/skyforge/values-prod-skyforge-local.yaml`,
the `master` role should not be pinned to a single worker. Keep at least two
healthy worker nodes in `skyforge.forwardCluster.nodeRoleReconciler.nodeRoles.master`
so `fwd-appserver` and `fwd-backend-master` can land on another node if the
original Longhorn attachment comes back in a bad post-reboot state.

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
4. Reconciles Forward DB auth to the role contract (`fwd_app` / `fwd_fdb`) and validates secret usernames.
5. Temporarily halts Infoblox VM during Forward recovery to avoid cold-start memory contention.
6. Restarts critical Forward and Skyforge workloads in deterministic order.
7. Unsuspends Infoblox lifecycle cronjobs and sets VM `runStrategy=Always` when present.
8. Waits for rollout completion and fails if unhealthy pods remain (strict mode).

Toggle this behavior with:

```bash
PAUSE_INFOBLOX_DURING_FORWARD_RECOVERY=false ./scripts/recover-prod-after-reboot.sh
```

## Contract

- This is a recovery path, not a replacement for normal deploy.
- Keep probe and restart logic in this script deterministic and idempotent.
- Any additional reboot failure mode should be added here with explicit checks.

## Forward scratch volume recovery

If Forward core or workers come back with logs like `Read-only file system` on
`/var/log/forward` or `/tmp`, and Longhorn shows the PVC as `attached` but not
fully usable, treat it as a node-local attach/mount failure rather than an app
configuration issue.

Recovery steps:

1. Confirm the affected pod is failing on writable paths such as
   `/var/log/forward` or `/tmp`.
2. Confirm the corresponding Longhorn volume is `attached` but the workload is
   still failing.
3. Temporarily cordon the affected node.
4. Delete the affected Forward pod so Kubernetes reschedules it and Longhorn
   reattaches the RWO volume onto a different healthy worker.
5. Wait for the replacement pod to become `Ready`.
6. Uncordon the original node only after the replacement workload is healthy.

Do not patch around this by making the Forward containers writable on rootfs or
by bypassing the scratch PVC mounts. The correct fix is to recover the volume
attachment and keep `fwd-master` placement available on more than one worker.
