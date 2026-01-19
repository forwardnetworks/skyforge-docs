# LabPP Restoration (TODO)

## Status

LabPP was previously supported as a first-class deployment/run type, implemented
as an in-cluster Kubernetes Job that runs `client-plus` in "labpp" mode and
connects to an external EVE-NG host over an SSH SOCKS tunnel.

During the Encore-native refactor (worker/taskengine split + typed config),
LabPP execution and UI affordances were removed/hidden:

- No `labpp` deployment type is accepted (`server/skyforge/project_deployments_api.go:normalizeDeploymentType`).
- No `labpp-run` task type exists in `server/internal/taskengine/`.
- Workspace LabPP fields are currently marked deprecated and omitted from JSON:
  `server/skyforge/workspace_types.go` (`LabppRunTemplateID`, `AllowCustomEveServers`, `EveServer`).

This doc captures the concrete work required to restore LabPP cleanly in the
current architecture.

## Desired UX (current expectation)

- Workspace settings gate LabPP with an enable/disable toggle.
- When enabled, the Create Deployment screen offers LabPP.
- LabPP must *not* configure Forward directly; it only generates the
  `data_sources.csv` (names + mgmt IPs) and Skyforge optionally syncs that CSV
  into Forward when the user enables Forward on the deployment.

## Implementation Plan

### 1) Restore the task type + worker execution

1. Add `TaskTypeLabppRun = "labpp-run"` to `server/internal/skyforgecore/contracts.go`.
2. Extend `server/internal/taskengine/engine.go` to dispatch `labpp-run` to a new handler.
3. Implement `server/internal/taskengine/labpp_task.go`:
   - Create a Kubernetes Job similar to the historical implementation in
     commit `0562147` (`server/skyforge/labpp_runner.go` + `task_runner.go`).
   - Stream job logs into task logs (reuse `kubeGetJobLogs`/`appendJobLogs` pattern).
   - On success, store generated artifacts (e.g. `data_sources.csv`) via the
     existing object store client (`server/internal/taskengine/objectstore.go`).
   - Treat late/irrelevant Forward checks from the runner as non-fatal (see
     commit `b51ef1b`).

### 2) Restore API surface to enqueue LabPP runs

Option A (recommended): Implement LabPP as a deployment type under the existing
`RunWorkspaceDeploymentAction` flow.

- Accept `"labpp"` in `normalizeDeploymentType`.
- Add a `case "labpp":` branch in `server/skyforge/project_deployments_api.go`
  to create a `labpp-run` task with a well-defined `spec` in task metadata.

Option B: Re-add a dedicated endpoint `POST /api/workspaces/:id/runs/labpp-run`
and have deployment actions call it (matches older architecture but is less
consistent with current generic action pattern).

### 3) Configuration / secrets

LabPP needs runner configuration and a stable EVE access method.

Historical env var keys still exist in chart infra files (legacy), but the
worker now relies on typed Encore config (`ENCORE_CFG_WORKER`).

Required configuration additions:

- Worker typed config:
  - LabPP runner image + pull policy
  - PVC name (where the runner reads/writes `/var/lib/skyforge`)
  - Platform data path (where CSV artifacts land)
  - NetBox integration inputs (optional)
  - Object storage endpoint + bucket + access/secret key (or reuse existing
    `ObjectStorage` and map to runner env vars)
- Secret requirements (already present in `deploy/skyforge-secrets.example.yaml`):
  - `eve-runner-ssh-key` (SSH key used by the runner to open the SOCKS tunnel)
  - `skyforge-labpp-netbox-*` (optional)

### 4) Workspace/UI gating

1. Expose an explicit workspace field for LabPP enablement (preferred) or reuse
   existing `AllowCustomEveServers` as a temporary gate.
2. Add UI controls on:
   - `portal-tanstack/src/routes/dashboard/workspaces/new.tsx`
   - `portal-tanstack/src/routes/dashboard/workspaces/$workspaceId.tsx`
3. Add LabPP provider to:
   - `portal-tanstack/src/routes/dashboard/deployments/new.tsx`
   - Hide unless the workspace gate is enabled.

### 5) EVE server selection (BYOS model)

If LabPP is BYOS (user supplies EVE-NG endpoint), reuse the existing workspace
server storage:

- `sf_project_eve_servers` (store exists; see `server/skyforge/workspace_servers_store.go`).

Missing pieces to implement:

- Add service endpoints to list/upsert/delete workspace EVE servers (mirrors the
  existing netlab server endpoints under `/api/workspaces/:id/netlab/servers`).
- Decide what labpp uses at runtime:
  - workspace-selected "default" EVE server, or
  - per-deployment EVE server reference.

## References (historical implementation)

- `0562147`: LabPP CSV download + EVE info fixes
- `274a3c9`: Run labpp with `--no-forwarding`
- `b51ef1b`: Ignore LabPP post-success forward checks

