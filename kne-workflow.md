# KNE (KNE) workflow

Skyforge supports deploying labs into Kubernetes using **kne** (referred to as **KNE** in the UI).

This is intended to let Skyforge scale “lab compute” horizontally by running labs as pods inside the k3s cluster (instead of SSHing to an external KNE/Netlab host).

## Designer authoring contract

- The lab designer is KNE-native end to end.
- Designer-authored topology YAML should not emit `runtime: containerlab` for normal container nodes.
- Runtime is only preserved in designer YAML when it is a meaningful KNE runtime contract, such as VM-class KubeVirt nodes.
- The left-side designer palette is catalog-only:
  - enabled Registry & NOS Catalog rows appear in the palette
  - uncataloged discovered repos do not appear there
  - built-in preset NOS fallbacks are not used
- External topology import uses preview-then-replace wizard semantics:
  - upload topology file
  - auto-detect source from filename/content with manual override
  - convert to canonical KNE designer YAML on the backend
  - review warnings/placeholders/image mappings
  - explicitly replace the current canvas
- Import is preserve-first:
  - unsupported infra/helper nodes are kept as placeholder nodes when the graph is still usable
  - missing image and similar mapping gaps are warnings, not blocking failures, unless the input is structurally unusable
- Startup config is a first-class node contract:
  - `path` mode preserves topology-backed startup config references
  - `inline` mode is stored in the designer sidecar and materialized on save under `.designer-startup/<template-base>/<node>.cfg`
  - saved topology YAML references those generated files through the normal KNE/netlab startup-config path

## How it works

### 1) KNE engine hard gate

- KNE is now **netlab-only** (`family=kne`, `engine=netlab`).
- Direct KNE `kne` engine/task paths are retired.
- Any remaining KNE records with non-netlab engine values fail closed at API preflight/action time.

### 2) Netlab → KNE (deployment family/engine: `kne` / `netlab`)

Netlab-on-KNE is a netlab-owned runtime flow where Skyforge orchestrates and persists state:

1. Skyforge syncs the Netlab template folder and runs netlab in-cluster (`kne/netlab` native mode).
   BYOS Netlab server mode is not used for this path.
2. Runtime entrypoint is unified:
   - `python3 /app/netlab.py up` for deploy/create
   - `python3 /app/netlab.py down` for destroy/stop
   - runtime startup fails fast if the image does not contain the native
     `netsim.providers.kne` contract expected by this checkout
3. `netlab up` generates:
   - `clab.yml`
   - `node_files/…`
   - recursive `config/**` startup configs (netlab-native output)
   - Skyforge does not post-process generated `node_files`; device bootstrap content comes from netlab output.
4. Netlab runtime writes a versioned manifest consumed by taskengine for graph/status persistence.
5. Skyforge stores topology/artifact pointers and DB contracts used by inventory/Forward sync.

### 2.0) Supported NOS onboarding scope

KNE onboarding in this workflow is intentionally limited to:

- `cEOS` (container runtime via CEOSLab controller)
- `IOL` / `IOLL2` (native Cisco node path)
- `IOS-XRd` (native Cisco node path)
- `kubevirt` runtime class (VM-backed NOS paths)

No additional KNE vendor controller stacks are required for this set.

### 2.1) Runtime contract: k8s-only

- KNE netlab runtime is hard-gated to `runtimeBackend=k8s`.
- No runtime toggle is exposed from Skyforge for docker fallback.
- Netlab runtime emits a k8s-only manifest contract, and taskengine rejects non-k8s backend values.
- KNE launcher/runtime paths in this deployment flow do not depend on Docker-in-Docker.
- Top-level provider semantics are `provider: kne`.
- Nested upstream `clab` node/image attributes remain valid where netlab uses
  them for container-based node metadata; Skyforge does not mass-rewrite those
  subtrees.

### Deploy policy + phased task events

- For `netlab-kne-run` deploy actions, Skyforge resolves deploy policy once per task
  (connectivity, expose mode, scheduling mode, resource flags, deploy timeout) and stores it
  in typed runtime contract storage (`sf_task_runtime_contracts.kne_deploy_policy`).
- Retries/resume of the same task re-use this persisted policy to prevent mid-run behavior drift
  when environment inputs change.
- Deploy tasks emit phased events under `kne.deploy.phase`:
  - `policy.resolved`
  - `cr.applied`
  - `pods.ready`
  - `native_mode.verified`
  - `topology_graph.captured`
  - `ssh_ready.completed` (kne-only when SSH readiness gating is enabled)

### Source of truth chain (Netlab → Skyforge → KNE)

- Netlab device metadata is generated from upstream `vendor/netlab/netsim/devices/*.yml` into
  `internal/taskengine/netlab_device_defaults.json`.
- Catalog generation materializes netlab SSH readiness defaults (`netlab_check_retries=20`,
  `netlab_check_delay=5`) when upstream device files do not set them, so runtime checks stay
  catalog-driven.
- For kne/netlab, canonical node device identity is sourced from netlab-generated
  manifest `nodes.*.deviceKey` and persisted into DB contract rows.
- The applier consumes generator output as-is; Skyforge no longer loads a node
  name-map ConfigMap or patches `hosts.yml` / `netlab.snapshot.pickle` at apply time.
- For kne/netlab apply behavior, Skyforge does not evaluate runtime `initial_policy`/SSH-auth
  gates; netlab runtime owns apply sequencing and per-device config semantics.
- Per-node license mounts (for example SR OS) are now explicit manifest contract
  fields under `nodeLicenses` (ConfigMap/key + absolute mount paths), generated by
  netlab runtime and consumed directly by taskengine.
- KNE/netlab persists canonical `device_key` and `forward_type` in
  `sf_netlab_node_status_current`; kne Forward sync consumes those DB fields directly.
- Non-kne Forward sync resolves device identity from node `kind+image` using the same catalog
  resolver and fails closed when a node cannot be resolved (no kind-only fallback table).
- SSH/auth readiness gates resolve node refs from topology graph metadata only and fail closed
  when kind/image metadata is missing.
- Forward device credential creation for netlab/kne sync is sourced from this same
  generated netlab catalog (no separate hardcoded credential table).
- Unknown or alias-only devices fail preflight (fail-closed).
- KNE/netlab tasks persist contract summaries in typed DB rows:
  - table: `sf_task_runtime_contracts`
  - fields include `netlab_catalog_provenance`, `netlab_contract`,
    `netlab_k8s_contract`, `netlab_node_resolution_summary`,
    `kne_deploy_policy`, `kne_compatibility_preflight`,
    `kne_capacity_preflight`, `kne_apply_summary`
  - task events remain emitted for run/audit timelines.
- KNE/netlab artifact index is persisted in typed DB rows:
  - table: `sf_netlab_artifact_index`
  - keyed by `(task_id, artifact_path)` with user/deployment/task foreign keys
  - historical `metadata.netlabArtifacts` is migrated and no longer the primary index
  - read API: `GET /api/users/:id/deployments/:deploymentID/netlab/artifacts`
  - `GET /api/netlab/runs` now resolves run artifact pointers from this typed index
    (legacy log-marker parsing `SKYFORGE_ARTIFACT` is removed).
- KNE apply step persists handoff checksum/provenance:
  - metadata key: `kneApplySummary`
  - task event: `kne.apply.summary`
- Pure-k8s runtime contract is fail-closed at reconcile time:
  - `env-files` in resolved node definitions are rejected for k8s runtime.
  - Node `binds` are allowed only when bind sources are artifact-backed via
    `spec.deployment.filesFromConfigMap` mounts for that node.
  - IOL/IOLL2 runtime paths are supported in native mode using dedicated
    k8s-native image tags and image-owned runtime wiring.
  - VM-class NOS nodes now carry an explicit KNE runtime contract in the
    topology protobuf (`node.runtime = KUBEVIRT_VM`) instead of relying on the
    old Skyforge-side `enableKubeVirtVMRuntime` deployment flag.
  - The netlab KNE plugin now emits canonical vendor/model/runtime tuples for
    VM-class nodes (for example `nxos -> vendor=CISCO, model=n9kv,
    runtime=KUBEVIRT_VM`).
  - VM disk images should be published as KubeVirt-compatible `containerDisk`
    images (disk at `/disk/disk.qcow2`) instead of vrnetlab runtime images.
    - helper: `scripts/build-kubevirt-containerdisk-from-vrnetlab.sh`
    - local qcow helper: `scripts/build-kubevirt-containerdisk-from-qcow2.sh`
    - Dell OS10 ZIP helper: `scripts/build-kubevirt-dellos10-from-zip.sh`
    - example conversion:
      - source: `ghcr.io/forwardnetworks/vrnetlab/vr-n9kv:9.3.8`
      - destination: `ghcr.io/forwardnetworks/kubevirt/vr-n9kv:9.3.8`
    - OS10 uses a three-disk KubeVirt contract from one image:
      - `/disk/disk.qcow2`
      - `/disk/hdb_OS10-installer.qcow2`
      - `/disk/hdc_OS10-platform.qcow2`
  - VM runtime classification is kind-driven with image-based kubevirt hints.
    If a VM node resolves to a `vrnetlab/*` image path, the runtime contract
    should be treated as invalid and converted to a `kubevirt/*`
    `containerDisk` image before deployment.
  - Startup configuration ownership remains in KNE via the existing
    `config_data` / `config_path` / `config_file` contract. Netlab/Skyforge do
    not inject a separate Skyforge-only VM startup-config bridge.
  - Cluster prerequisite for VM-class NOS in native mode: KubeVirt CRDs/API
    (`kubevirt.io/v1`) must be installed; VM runs fail fast when unavailable.
  - KNE now creates a per-node fabric contract ConfigMap
    (`<node>-fabric-contract`) and annotates/labels launcher + VM resources with
    that contract reference.
    - Contract generation excludes management interface `eth0` and incomplete
      link entries, keeping fabric reconciliation scoped to data-plane links.
  - KNE now runs a kubevirt fabric reconciliation loop after node creation:
    it resolves live `virt-launcher` pod names, parses each node fabric
    contract, and updates meshnet Topology CRs so link peer-pod references
    target the resolved VM runtime pod identities.
    - reconciled Topology CRs are marked managed with
      `kne.forwardnetworks.com/kubevirt-fabric-managed=true` and owner
      annotation `kne.forwardnetworks.com/kubevirt-fabric-owner-node=<node>`
      so stale runtime-pod topology objects can be cleaned safely on pod-name
      rotation.
  - KNE now waits for meshnet Topology status readiness on resolved VM runtime
    pods (`status.net_ns` + `status.container_id`) and fails fast if fabric
    status does not converge within the reconcile timeout window.
  - Non-Cisco VM-class nodes (for example Juniper/Nokia/host-backed FortiOS)
    now use the same KNE native KubeVirt runtime path when
    `node.runtime = KUBEVIRT_VM`:
    - KNE creates/updates VirtualMachine resources directly from topology
      contract fields (`config.image`, startup-config, constraints, services).
    - KNE service selectors target `kubevirt.io/domain=<node>` consistently
      across vendors.
  - Optional VM guest secondary-interface bridge:
    - feature gate env: `KNE_KUBEVIRT_SECONDARY_INTERFACES=true` (per node)
    - KNE creates/updates per-link `NetworkAttachmentDefinition` resources and
      wires VM interfaces/networks from the node fabric contract.
    - KNE waits for expected guest interface names to appear on VMI status
      before marking node creation complete.
    - gate is fail-closed and disabled by default.
  - Guest-NIC hotplug/attach beyond current runtime-pod link reconciliation
    remains follow-up work.
- Netlab generator handoff uses a single manifest contract:
  - contract: `skyforge.netlab-kne.manifest`
  - schema file: `components/server/internal/taskengine/netlab_kne_manifest.schema.json`
  - required top-level fields: `contractVersion`, `bundleSha256`, `kneTopologyTextProto`, `applyPlan`, `nodeNameMap`, `nodes`, `k8s`
  - optional strict field: `nodeLicenses` (per-node ConfigMap/key + mount path contract)
  - generator validates schema before publishing `manifest.json`
  - taskengine validates schema at ingress before unmarshal/use
  - contract validation is hard-required (no runtime fallback toggle)
  - if startup configs are referenced in the manifest apply plan, runtime requires those files to be artifact-backed in per-node `node_files` mounts
- KNE deploy policy is persisted in deployment config (`deployPolicy`) and
  written to typed runtime-contract rows in `sf_task_runtime_contracts`
  (not environment overrides).
- Preflight now runs at API-time before runs are queued:
  - API/CRD compatibility preflight (default enabled in `deployPolicy.compatibilityPreflight`)
  - capacity preflight (default enforced in `deployPolicy.failOnInsufficientResources`)
  - capacity preflight compares requested topology resources vs current allocatable-minus-requested node headroom
  - headroom reserves are configurable per deployment policy:
    - `deployPolicy.capacityReserveCpuPercent` (default `10`)
    - `deployPolicy.capacityReserveMemoryPercent` (default `10`)
- when capacity is insufficient at execution time, tasks are re-queued with bounded exponential backoff instead of immediately failing:
    - metadata keys: `capacityRetryCount`, `capacityRetryAt`
    - events: `task.requeued`, `task.requeued.capacity`
- queued task fairness + TTL behavior is enforced by the worker:
  - per-user topology-run cap (default `1`) re-queues overflow tasks with
    linear fairness delay (`task.requeued.fairness`)
  - queue TTL (default `1800s`) fails stale queued tasks with
    `task.expired.ttl` and a terminal task error
  - defaults are configured in `skyforge.config.Worker`:
    - `PerUserTopologyRunCap`
    - `FairnessRequeueDelaySeconds`
    - `QueueTTLSeconds`
- deployment action responses now include queue state when an operation is queued:
  - `queue.queueDepth`
  - `queue.position`
  - `queue.nextRetryAt`
  - `queue.expiresAt`
- Skyforge also exposes an explicit preflight endpoint (no queue side-effects):
  - `POST /api/users/:id/deployments/:deploymentID/preflight`
  - supported for deployment family/engine pair `kne/netlab`
  - returns no-op/idempotent reasons when deployment state already matches requested action
- Deployment action/preflight requests now use a short-lived advisory operation lock keyed by
  deployment operation key, which prevents duplicate clicks from running concurrent
  preflight+queue paths for the same deploy/destroy operation.
- The run detail UI (`/dashboard/runs/:runId`) consumes lifecycle/provenance events from:
  - `/api/runs/:id/events` (stdout/stderr stream)
  - `/api/runs/:id/lifecycle` (structured phase/provenance events)

## Deployment delete semantics

- Deployment delete is force-delete for the Skyforge deployment definition.
- UI/API delete remains available regardless of current deployment lifecycle state.
- Force-delete removes the `sf_deployments` row immediately and is intended as a deterministic recovery path for stuck or partial state transitions.
- Optional Forward network deletion (`forwardDelete=true`) still requires valid Forward credentials and will fail if Forward-side deletion fails.

## What’s still “phase 2” / future work

- Additional post-apply runtime hooks beyond the native netlab/KNE lifecycle.
  - Current contract is:
    - `kne create`
    - upstream KNE provider `post_start_lab` inventory refresh
    - `netlab initial`
  - If we need more post-up work in the future, it should extend the existing
    runtime hook/apply seam instead of bypassing it with ad hoc taskengine
    mutations.

## Ops / prerequisites

- Helm: `values.yaml` has `skyforge.kne.enabled` (experimental).
- RBAC: Skyforge server needs to be able to `get/list/create/update/delete`:
  - `topologies.kne.kne.dev`
  - `configmaps`
  - `namespaces`

## Troubleshooting

- Native KNE NOS smoke matrix (GHCR images from runtime defaults):
  - `./scripts/smoke-kne-nos-native.sh`
  - Uses `components/server/netlab/runtime/defaults.yml` as source-of-truth for
    per-device image pins.
  - Pass criteria per NOS: topology create succeeds, node reaches `Running/Ready`,
    and topology namespace is deleted cleanly.

- If `Topology` never becomes ready:
  - `kubectl -n <ns> get topologies`
  - `kubectl -n <ns> describe topology <name>`
  - check kne manager logs: `kubectl -n skyforge logs deploy/kne-manager`
- If node pods constantly restart (Deployment `kubectl.kubernetes.io/restartedAt` keeps changing):
  - root cause is usually the kne controller thinking configs changed every reconcile.
  - ensure the kne manager image is built with the “restart on config hash” fix (Skyforge tags around `20260119-restart-hash-*`).
- If you see `topology capture failed: Access Denied`:
  - the Skyforge worker stores topology graph artifacts in the `skyforge-files` bucket.
  - ensure the configured object-storage principal referenced by `SKYFORGE_OBJECT_STORAGE_ACCESS_KEY` has write access to `skyforge-files/*`.
- If KNE/netlab deploy fails early:
  - confirm the Netlab server can run `netlab create` and produce `clab.yml` and `node_files/`.
