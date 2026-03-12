# Marketing Snapshot Config Changes Plan

## Summary

This plan adds a first-class configuration change workflow for long-lived shared
Forward demo environments, starting with the standard marketing snapshot.

The core rule is strict:

- do not build a second configuration push engine
- reuse the existing Skyforge netlab render and apply path wherever possible
- model every change as a durable, auditable change run

The resulting system should feel like a controlled change pipeline, not an SSH
button.

## Goals

- let snapshot operators submit ACL, route, interface, and similar config changes
- preserve one execution backend for rendered config pushes
- provide diff-first review, approval, execution, and verification
- keep the implementation Encore-native and task-engine-driven
- make the standard marketing snapshot a protected target with clear approval and
  rollback semantics

## Non-Goals

- direct per-device imperative SSH actions from the UI
- a second bespoke renderer outside the netlab/taskengine path
- freeform arbitrary scripts as the default path
- replacing the existing deployment workflow

## Existing Reuse Seam

The current reusable execution seam already exists in the backend:

- `components/server/skyforge/task_specs.go`
  - task contracts for `netlab` and `netlab-c9s`
- `components/server/skyforge/deployment_create_validation.go`
  - bundle extraction and netlab/clabernetes validation
- `components/server/internal/taskengine/netlab_task_run.go`
  - remote netlab API execution model
- `components/server/internal/taskengine/netlab_c9s_run.go`
  - in-cluster render/apply workflow
- `components/server/internal/taskengine/netlab_c9s_apply_deploy.go`
  - the in-cluster job contract that actually performs the deployment-side apply

The concrete boundary to preserve is:

- queued control-plane task type: `netlab-c9s-run`
- runtime manifest contract: `skyforge.netlab-c9s.manifest/v1`

That manifest boundary is the right future split between review/render and
approved apply. The config-change pipeline should persist and hand off that same
contract rather than invent a second execution format.

This plan should continue through that seam, not around it.

## Product Model

### Change Run

A change run is the durable resource for every requested config change.

Required fields:

- target type: `snapshot`, `deployment`, `environment`
- target ref: stable identifier for the protected environment or deployment
- source kind:
  - `netlab-model`
  - `config-snippet`
  - `structured-patch`
  - `ansible-playbook`
  - `shell-script`
- execution mode:
  - `dry-run`
  - `staged`
  - `apply`
- summary / reason
- ticket reference
- requested by / approved by
- immutable spec payload
- lifecycle event stream

### Lifecycle

Target lifecycle states:

- `requested`
- `validating`
- `rendered`
- `awaiting-approval`
- `approved`
- `queued`
- `applying`
- `verifying`
- `succeeded`
- `failed`
- `cancelled`
- `rolled-back`

## UX Shape

Primary workflow group:

- `Operations`
  - `Config Changes`

Pages:

1. `Queue`
- current and historical change runs
- filter by target, ticket, status, requester

2. `New Change`
- choose target environment
- choose change method
- enter summary, ticket, and intent payload

3. `Review`
- rendered artifacts
- per-device diff
- impacted devices
- verification expectations

4. `Approvals`
- protected targets like the standard marketing snapshot
- explicit approve/reject actions

5. `Runs`
- lifecycle, logs, per-device results, rollback pointers

## Execution Architecture

### Preferred source path

1. user submits model-backed or structured change intent
2. Skyforge builds a canonical change-run spec
3. validation normalizes the change into renderable config artifacts
4. execution queues through the task engine
5. the apply step reuses the same netlab/clabernetes config push path used by
   normal deployments
6. verification runs and optionally triggers Forward recollect

### Escape hatches

Supported later, but still on the same contract:

- `ansible-playbook`
- `shell-script`

These must still become change runs and go through review, approval, apply, and
verification. They must not bypass the durable control-plane model.

## API Design Principles

Keep the API resource-oriented and Encore-native.

### Domain service

Create a dedicated `configchanges` Encore service.

Responsibilities:

- change-run contracts
- persistence
- lifecycle events
- approval state
- execution orchestration handoff

### Edge wrappers

Expose thin authenticated wrappers from `components/server/skyforge`.

Proposed routes:

- `GET /api/config-changes`
- `POST /api/config-changes`
- `GET /api/config-changes/:id`
- `GET /api/config-changes/:id/lifecycle`
- `POST /api/config-changes/:id/status`

Admin routes later:

- `GET /api/admin/config-changes`
- `POST /api/admin/config-changes/:id/approve`
- `POST /api/admin/config-changes/:id/reject`
- `POST /api/admin/config-changes/:id/execute`

Do not add a dashboard-style mega endpoint.

## Phased Implementation

### Phase 1: Control-plane scaffold

- add `configchanges` service
- add DB tables for change runs and lifecycle events
- add authenticated list/create/get/lifecycle APIs
- add durable status update API for future workers and approvals
- no execution yet

### Phase 2: Review and render contract

- validate and normalize source payloads
- generate rendered change artifacts
- persist per-device preview/diff artifacts
- keep execution disabled until review path is stable

Current status:

- durable render/review contracts are implemented in the `configchanges` service
- supported previewable source kinds today:
  - `config-snippet`
  - `structured-patch`
  - `netlab-model`
- render stores:
  - normalized spec JSON
  - typed review JSON
  - rendered timestamp
- the authenticated API surface now includes:
  - `POST /api/config-changes/:id/render`
  - `GET /api/config-changes/:id/review`
- review intentionally stops before real device apply; the queue/apply seam is
  scaffolded but not exposed yet

### Phase 3: Apply through existing netlab path

- add change-run task specs
- hand off approved changes into the existing netlab apply seam
- start with a protected target: standard marketing snapshot
- first supported methods:
  - ACL changes
  - interface admin state changes
  - static route changes

Current status:

- execution-task linkage is now part of the durable change-run model
- a dedicated control-plane task type exists for future apply handoff:
  - `config-change-run`
- internal queue scaffolding stores the planned execution adapter alongside the
  normalized spec and review payload
- executable admin queueing is now live for the first protected path:
  - `POST /api/admin/config-changes/:id/execute`
- the worker task now reuses the existing `netlab-c9s` seam directly for:
  - `targetType=deployment`
  - `sourceKind=netlab-model`
  - template-backed C9S deployments only
- deployment-targeted queueing now resolves the actual target deployment scope
  instead of falling back to "latest scope for username"
- unsupported source kinds and topologyPath-only netlab edits still stop at
  review and are not executed yet

### Phase 4: Verification and rollback

- collect per-device result state
- attach rollback payloads/artifacts
- trigger Forward recollect or post-check task
- record verification results in lifecycle events

Current status:

- durable rollback and execution evidence are now persisted on change runs
- the change-run model now stores:
  - rollback summary
  - execution summary
  - execution task linkage
- apply captures rollback evidence before execution, including:
  - previous topology artifact key
  - previous node-status summary
- apply and verify now persist execution evidence, including:
  - topology artifact key produced by the apply seam
  - node-status counts
  - task-scoped artifact references
  - verification warnings
- verification is now materially stronger than "artifact exists":
  - deployment topology-current row must exist
  - topology-current row must point at the current task
  - topology-current source must be `netlab-c9s`
  - topology-current node count must be non-zero
  - the topology artifact object must be readable
  - current node-status rows must exist for the deployment
  - task artifact-index entries must exist for the execution task
- the operator UI now exposes:
  - rollback evidence captured before apply
  - execution evidence captured after apply/verify
  - task/artifact/verification summaries on the selected run
- the first worker-side tests now cover:
  - rollback summary aggregation
  - execution summary construction
  - planned execution-task extraction from review payload
- the durable persistence seam now also has store-level coverage for:
  - create-time rollback and execution summary persistence
  - execution-artifact summary updates
  - lifecycle event emission on those writes
- the queue/execute handoff now has direct test coverage for:
  - deployment-target queue resolution
  - dedupe short-circuiting
  - task-spec metadata shape
  - queue handoff request shape

### Phase 5: Broader source support

- model-backed edits
- structured patch library
- ansible/script escape hatches for privileged operators

## Approval and Policy

Protected shared targets must require approval.

The standard marketing snapshot should default to:

- protected target
- approval required
- explicit ticket reference required
- change history retained
- rollback artifacts retained

Current status:

- admin operator routes now exist for:
  - list
  - get
  - review
  - lifecycle
  - approve
  - reject
  - execute
- the first portal surface now supports:
  - current-user create/list/render/review
  - admin list/review/lifecycle across all runs
  - admin approve/reject/execute controls on executable runs
- approval and execution remain explicit separate actions; approval does not
  auto-queue apply

RBAC/policy wiring should be integrated with the existing platform policy model,
not a new permission system.

## Testing

### Phase 1

- change run create/list/get/lifecycle server tests
- migration applies cleanly
- ownership and admin visibility checks in wrapper APIs

### Later phases

- rendered artifact diff tests
- task handoff tests through netlab apply seam
- rollback artifact creation tests
- end-to-end approval/apply/verify workflow tests

## Immediate Next Slice

The next meaningful slice is:

- broaden executable source support beyond template-backed `netlab-model`
- persist explicit rollback artifact references from the apply seam
- add post-apply verification richer than topology-artifact presence
- add focused end-to-end tests for approve -> execute -> task lifecycle
