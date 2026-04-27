# Control-plane and workload isolation

Production Skyforge clusters should keep etcd/API nodes isolated from Forward,
Skyforge application pods, lab pods, and Longhorn data replicas when there are
enough reliable nodes to make that separation useful. The historical six-node
split is:

- Control-plane/etcd: `skyforge-worker-0`, `skyforge-worker-3`,
  `skyforge-worker-4`
- Workload/storage: `skyforge-worker-1`, `skyforge-worker-2`,
  `skyforge-worker-5`

The chart-backed node role reconciler is the source of truth for Forward role
labels and `skyforge.forwardnetworks.com/pool-class`. Do not manually add
`pool-class=app`, `forwardnetworks.com/role=forward`, or `node-role.kubernetes.io/fwd-*`
labels to control-plane nodes except as a temporary rollback.

## Local single-node exception

The current local production profile is intentionally single-node on
`skyforge-worker-0`. In that profile, `deploy/skyforge-values.yaml` is the
source of truth and assigns the app pool plus all Forward roles to
`skyforge-worker-0`. `controlPlaneTaint.enabled` stays `false`; otherwise
normal app, Forward, Gitea, Coder, and lab pods can become unschedulable on the
only node.

`skyforge.forwardCluster.contractValidation.allowForwardOnControlPlane=true`
is required for this profile because Kubernetes still labels the only node as a
control-plane node. Leave that setting `false` for multi-node profiles where
Forward should stay off dedicated etcd/API nodes.

This is not a workaround node label state. It is the supported profile for the
local k3s environment when the remaining VMs are powered off or unreliable. The
guardrails are scheduler accounting, app/lab priority separation, resource
request admission for `user-*` labs, and Longhorn `defaultReplicaCount: 1`.

If the cluster is moved back to a multi-node topology, first create a dedicated
multi-node values overlay and then re-enable control-plane taints, app-pool
placement, and Longhorn HA replica placement together. Do not partially rejoin
old workers without updating the node role reconciler values, or the reconciler
will remove/restore labels according to the checked-in single-node contract.

Control-plane nodes must also carry a `NoSchedule` taint so KNE/netlab lab pods
and other generic workloads cannot land there when they do not use an app-pool
selector:

```bash
kubectl taint node skyforge-worker-0 skyforge-worker-3 skyforge-worker-4 \
  node-role.kubernetes.io/control-plane=:NoSchedule --overwrite
```

Only system workloads and storage/control-plane components with explicit
tolerations should run there. The rollback is to remove that taint from the
control-plane nodes.

In chart-managed clusters, enable
`skyforge.forwardCluster.nodeRoleReconciler.controlPlaneTaint.enabled` so the
same reconciler that owns pool labels also keeps the control-plane taint
present after node rejoin or rebuild.

Forward compute/search anti-affinity is preferred, not required, in this local
production profile so the configured worker replica count can fit on the three
workload nodes. Longhorn data scheduling should be disabled on control-plane
nodes and replicas should be evicted one node at a time after all workloads have
moved.

Validation gates:

- Control-plane nodes should run only control-plane-critical pods and required
  DaemonSets.
- Forward compute/search/NQE, Skyforge collectors/workers, Gitea, Coder
  workspaces, and lab workloads should run on workload/storage nodes.
- Longhorn volumes should be healthy with no data replicas scheduled on
  control-plane nodes.
- Shared Postgres connections should stay below the operational ceiling after
  Forward worker rollouts.

Production values pin these workload classes to `pool-class=app`:

- Skyforge API and task worker deployments.
- PVC-backed platform services that use `skyforge.coreStatefulPlacement`, such
  as Postgres, Redis, Gitea, and S3 gateway.
- Dex and Coder, while preserving any additional egress/Okta node selectors.
- Redoc, SSO proxy deployments, NSQ, Forward core pods, and Forward
  compute/search/NQE workers.
- Forward compute/search workers should require both their Forward node-role
  label and `pool-class=app`; this keeps stale role labels on control-plane
  nodes from making them eligible.
- When Skyforge owns Forward worker placement, `fwd-autopilot` must not be able
  to patch Kubernetes Node labels. The upstream Forward autopilot assumes the
  stock StatefulSet worker layout and can re-add stale
  `node-role.kubernetes.io/fwd-compute-worker` and
  `node-role.kubernetes.io/fwd-search-worker` labels to control-plane nodes.
  If that drift appears, remove only the `patch` verb from the
  `fwd-autopilot-role` ClusterRole's `nodes` rule and keep `list/watch` for
  visibility. Restore by re-adding `patch` if Forward autopilot is returned to
  ownership of worker placement.

Longhorn scheduling is managed outside this Helm chart. During a control-plane
isolation migration, disable Longhorn scheduling and request eviction on the
control-plane nodes, then monitor replica drain to zero before considering the
storage split complete.

## Lab workload safeguards

KNE/netlab device pods are not platform services. They may share worker nodes
with Skyforge, Forward, and Longhorn, but Skyforge does not inject or require
Kubernetes CPU/memory requests or limits for native KNE topology pods. Runtime
pod shape stays owned by the native netlab/KNE provider path instead of a
Skyforge admission-policy contract.

Platform workloads should use `skyforge-core` priority while labs use lower
priority where the runtime supports it. Cluster-wide launch preflight still
enforces aggregate pool headroom before a deployment is queued.
