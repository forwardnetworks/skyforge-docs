# C9s (Clabernetes) workflow

Skyforge supports deploying labs into Kubernetes using **clabernetes** (referred to as **C9s** in the UI).

This is intended to let Skyforge scale “lab compute” horizontally by running labs as pods inside the k3s cluster (instead of SSHing to an external Containerlab/Netlab host).

## How it works

### 1) Containerlab → C9s (deployment family/engine: `c9s` / `containerlab`)

- User selects a **Containerlab topology** template (YAML) from either:
  - public blueprints (`blueprints/containerlab`), or
  - the user repo.
- Skyforge creates a `Topology` custom resource:
  - `apiVersion: clabernetes.containerlab.dev/v1alpha1`
  - `kind: Topology`
  - `spec.definition.containerlab: "<containerlab yaml>"`
- clabernetes reconciles the Topology and launches the node pods.

Notes:
- There is no separate “conversion” step required: clabernetes accepts the Containerlab YAML directly via `spec.definition.containerlab`.
- Skyforge places each user scope into its own Kubernetes namespace by default:
  `ws-<userScopeSlug>` (sanitized).

### 2) Netlab → C9s (deployment family/engine: `c9s` / `netlab`)

Netlab-on-C9s uses Netlab only as a generator of Containerlab artifacts, then deploys those artifacts to Kubernetes via clabernetes:

1. Skyforge syncs the Netlab template folder and runs Netlab generation in-cluster
   via Kubernetes Job (`c9s/netlab` native mode). BYOS Netlab server mode is not
   used for this path.
2. Runs `netlab create` to generate:
   - `clab.yml`
   - `node_files/…`
   - `config/*.cfg` startup configs (netlab-native output)
   - Skyforge does not post-process generated `node_files`; device bootstrap content comes from netlab output.
3. Exports the generated artifacts as a `containerlab-<deployment>.tar.gz` tarball.
4. Skyforge parses the tarball:
   - extracts `clab.yml`
   - extracts per-node `node_files/<node>/*`
   - extracts generated startup configs from `config/*.cfg`
5. Skyforge creates one ConfigMap per node containing that node’s `node_files`, labeled with:
   - `skyforge-c9s-topology=<topologyName>`
6. Skyforge creates a clabernetes `Topology` that mounts both `node_files` and startup-config ConfigMaps using `spec.deployment.filesFromConfigMap`.

This gives an end-to-end “Netlab template → k8s lab” path without needing an external Containerlab host.

### Deploy policy + phased task events

- For `clabernetes-run` deploy actions, Skyforge resolves deploy policy once per task
  (connectivity, expose mode, scheduling mode, resource flags, deploy timeout) and stores it
  in task metadata as `clabernetesDeployPolicy`.
- Retries/resume of the same task re-use this persisted policy to prevent mid-run behavior drift
  when environment inputs change.
- Deploy tasks emit phased events under `clabernetes.deploy.phase`:
  - `policy.resolved`
  - `cr.applied`
  - `pods.ready`
  - `native_mode.verified`
  - `topology_graph.captured`
  - `ssh_ready.completed` (containerlab-only when SSH readiness gating is enabled)

### Source of truth chain (Netlab → Skyforge → Clabernetes)

- Netlab device metadata is generated from upstream `vendor/netlab/netsim/devices/*.yml` into
  `internal/taskengine/netlab_device_defaults.json`.
- Catalog generation materializes netlab SSH readiness defaults (`netlab_check_retries=20`,
  `netlab_check_delay=5`) when upstream device files do not set them, so runtime checks stay
  catalog-driven.
- Skyforge resolves node device identity strictly from this generated catalog in order:
  1. exact `device`
  2. `clab_kind`
  3. `image_prefix`
- For c9s/netlab apply behavior, Skyforge does not evaluate runtime `initial_policy`/SSH-auth
  gates; netlab runtime owns apply sequencing and per-device config semantics.
- C9s/netlab persists canonical `device_key` and `forward_type` in
  `sf_netlab_node_status_current`; c9s Forward sync consumes those DB fields directly.
- Non-c9s Forward sync resolves device identity from node `kind+image` using the same catalog
  resolver and fails closed when a node cannot be resolved (no kind-only fallback table).
- SSH/auth readiness gates resolve node refs from topology graph metadata only and fail closed
  when kind/image metadata is missing.
- Forward device credential creation for netlab/clabernetes sync is sourced from this same
  generated netlab catalog (no separate hardcoded credential table).
- Unknown or alias-only devices fail preflight (fail-closed).
- C9s/netlab tasks persist catalog provenance in task metadata/event:
  - metadata key: `netlabCatalogProvenance`
  - task event: `netlab.catalog.provenance`
- C9s/netlab tasks also persist node resolution summary:
  - metadata key: `netlabNodeResolutionSummary`
  - task event: `netlab.node_resolution.summary`
- Clabernetes apply step persists handoff checksum/provenance:
  - metadata key: `clabernetesApplySummary`
  - task event: `clabernetes.apply.summary`
- Netlab generator handoff uses a versioned manifest contract:
  - contract version: `skyforge.netlab-c9s.manifest/v1`
  - schema file: `components/server/internal/taskengine/netlab_c9s_manifest.schema.json`
  - required top-level fields: `contractVersion`, `bundleSha256`, `clabYAML`, `nodes`, `netlabOutput`
  - generator validates schema before publishing `manifest.json`
  - taskengine validates schema at ingress before unmarshal/use
  - contract validation is hard-required (no runtime fallback toggle)
- Clabernetes deploy policy is persisted in deployment config (`deployPolicy`) and
  passed as typed task metadata (not environment overrides).
- Preflight now runs at API-time before runs are queued:
  - API/CRD compatibility preflight (default enabled in `deployPolicy.compatibilityPreflight`)
  - capacity preflight (default hard-fail in `deployPolicy.failOnInsufficientResources`)
  - capacity preflight compares requested topology resources vs current allocatable-minus-requested node headroom
- Skyforge also exposes an explicit preflight endpoint (no queue side-effects):
  - `POST /api/users/:id/deployments/:deploymentID/preflight`
  - supported for deployment family/engine pairs `c9s/containerlab` and `c9s/netlab`
  - returns no-op/idempotent reasons when deployment state already matches requested action
- Deployment action/preflight requests now use a short-lived advisory operation lock keyed by
  deployment operation key, which prevents duplicate clicks from running concurrent
  preflight+queue paths for the same deploy/destroy operation.
- The run detail UI (`/dashboard/runs/:runId`) consumes these metadata keys and
  lifecycle events from:
  - `/api/runs/:id/events` (stdout/stderr stream)
  - `/api/runs/:id/lifecycle` (structured phase/provenance events)

## What’s still “phase 2” / future work

- Post-deploy configuration steps executed *after* the C9s topology becomes ready.
  - Linux nodes are configured by running the netlab-generated `node_files/<node>/{initial,routing}` scripts directly in-pod.
  - Network OS nodes are configured via startup configs mounted at boot time.
  - If we need additional post-up work in the future, it should be implemented in Go (worker/taskengine) rather than via Ansible jobs.

## Ops / prerequisites

- Helm: `values.yaml` has `skyforge.clabernetes.enabled` (experimental).
- RBAC: Skyforge server needs to be able to `get/list/create/update/delete`:
  - `topologies.clabernetes.containerlab.dev`
  - `configmaps`
  - `namespaces`

## Troubleshooting

- If `Topology` never becomes ready:
  - `kubectl -n <ns> get topologies`
  - `kubectl -n <ns> describe topology <name>`
  - check clabernetes manager logs: `kubectl -n skyforge logs deploy/clabernetes-manager`
- If node pods constantly restart (Deployment `kubectl.kubernetes.io/restartedAt` keeps changing):
  - root cause is usually the clabernetes controller thinking configs changed every reconcile.
  - ensure the clabernetes manager image is built with the “restart on config hash” fix (Skyforge tags around `20260119-restart-hash-*`).
- If you see `topology capture failed: Access Denied`:
  - the Skyforge worker stores topology graph artifacts in the `skyforge-files` bucket.
  - ensure the configured object-storage principal referenced by `SKYFORGE_OBJECT_STORAGE_ACCESS_KEY` has write access to `skyforge-files/*`.
- If C9s/netlab deploy fails early:
  - confirm the Netlab server can run `netlab create` and produce `clab.yml` and `node_files/`.
