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

### Bundled hook lanes

The widened source kinds still use the same contract:

- `ansible-playbook`
- `shell-script`

These are not separate executors. They become executable only as deterministic
bundled `post-apply` runtime hooks inside the existing `netlab-c9s` seam.

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
  - `sourceKind=structured-patch`
  - `sourceKind=config-snippet`
  - template-backed C9S deployments only
- `config-snippet` now uses a topology/bundle-backed execution contract:
  - snippet lines compile into generated per-device startup-config sidecars
  - `topology.yml` is patched so targeted nodes reference those sidecars
    through `clab.startup-config`
  - the resulting bundle still executes through the same `netlab-c9s`
    patched-bundle seam
- `structured-patch` now uses a standards-based execution contract:
  - RFC 6902 JSON Patch operations
  - applied to the source `topology.yml`
  - then repackaged into a patched netlab bundle
  - and executed through the same `netlab-c9s` runtime seam
- the same queued `config-change-run` task contract now supports:
  - `action=execute`
  - `action=rollback`
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

- execution evidence now captures per-device results from
  `sf_netlab_node_status_current`, including management reachability fields and
  runtime task ownership
- the operator UI now exposes a dedicated per-device verification surface with:
  - reachable vs non-reachable counts
  - management endpoint visibility
  - per-device execution task ownership
  - device-scoped verification hints
- rollback evidence now stores the previous deployment config JSON so rollback
  can replay the same `netlab-c9s` seam instead of inventing a second apply
  path
- admin rollback is now queued through the same durable control-plane task type:
  - `POST /api/admin/config-changes/:id/rollback`
- rollback remains intentionally scoped to the first executable lane:
  - `targetType=deployment`
  - `sourceKind=netlab-model`
  - `sourceKind=structured-patch`
  - template-backed C9S deployments

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
  - lifecycle phase timeline for the selected run
  - per-device verification detail as a separate operator card
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
- the configchanges service now has direct lifecycle coverage for:
  - queue execution state transition
  - queue rollback state transition
  - queued task id persistence on the run record

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
- the create flow now defaults to the safe executable lane:
  - `targetType=deployment`
  - `sourceKind=structured-patch`
  - executable vs bounded-review-only source kinds are explicitly labeled in the
    UI
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
- admin wrapper tests for:
  - approve state guards
  - execute eligibility for `netlab-model`, `structured-patch`,
    `config-snippet`, `ansible-playbook`, and `shell-script`
  - rollback eligibility for the same supported lanes
- stateful operator-flow test for:
  - approve -> execute -> rollback on a supported `structured-patch` run
- render-state transition proof for:
  - `structured-patch` apply-mode runs entering `awaiting-approval`
- focused portal tests for:
  - executable vs bounded-review-only source labels
  - selected-run operator gating
- end-to-end approval/apply/verify workflow tests

## Immediate Next Slice

The plan is complete for the safe executable scope:

- `targetType=deployment`
- `sourceKind=netlab-model`
- `sourceKind=structured-patch`
- `sourceKind=config-snippet`
- `sourceKind=ansible-playbook`
- `sourceKind=shell-script`
- template-backed C9S deployments

Future expansion, if needed, should be treated as a new follow-on track:

- broaden operator-flow testing to full rendered/apply/verify lifecycle
- decide whether any source kinds beyond the current safe lanes are worth
  supporting

## Follow-on Design: Topology/Bundle-Backed Execution Contract

If new source kinds become executable later, they must not introduce a
second apply path. The only acceptable execution target is still the existing:

- queued control-plane task type: `netlab-c9s-run`
- runtime manifest contract: `skyforge.netlab-c9s.manifest/v1`

The design rule is:

- every executable change source must normalize into a patched topology bundle
- the worker must still hand the result to the same `netlab-c9s` seam
- review, approval, rollback, and verification continue to operate on the same
  durable change-run resource

### Contract Shape

Add a normalized execution contract to the review payload for follow-on source
kinds:

- `executionPath`
  - `planned-netlab-c9s-patched-bundle`
- `bundleTransform`
  - `topology-json-patch`
  - `topology-overlay`
  - `generated-sidecar`
- `bundleInputs`
  - source topology bundle reference
  - source topology path within the bundle
  - optional sidecar artifact references
- `bundleOutputs`
  - patched topology bundle reference
  - rollback bundle reference or previous deployment config reference

The worker remains responsible for materializing the patched bundle only after
approval and queueing. The control plane persists the normalized transform
contract, not an imperative execution recipe.

### Source-Kind Mapping

#### `config-snippet`

`config-snippet` becomes executable only after it compiles into a topology-level
change contract.

Required normalization:

- parse the device-scoped snippet request
- map it to device targets in the source topology
- generate a deterministic sidecar artifact inside the bundle, for example:
  - `skyforge/changes/<run-id>/device-snippets/<device>.cfg`
- patch `topology.yml` so the targeted nodes reference the generated sidecar
  through the same startup/config hooks already honored by netlab

This keeps the runtime path topology-backed. The snippet is never pushed
directly to devices from the control plane.

#### `ansible-playbook`

`ansible-playbook` now executes as a deterministic bundle extension.

Current normalization:

- vendor the approved playbook into the generated bundle under:
  - `skyforge/changes/<run-id>/ansible/playbook.yml`
- emit `skyforge/runtime-hooks.json`
- execute the playbook as a bounded `post-apply` hook through the same
  `netlab-c9s` runtime entrypoint

#### `shell-script`

`shell-script` now executes as the most restricted bundled hook lane.

Current normalization:

- store script content as a generated bundle artifact:
  - `skyforge/changes/<run-id>/hooks/post-apply.sh`
- emit `skyforge/runtime-hooks.json`
- execute it as a bounded `post-apply` hook in the same `netlab-c9s` runtime

Freeform shell outside the bounded hook model remains out of scope.

### Required Manifest Evolution

Do not add a second runtime manifest. Extend the existing
`skyforge.netlab-c9s.manifest/v1` boundary only if needed with explicit optional
fields such as:

- `topologyBundleB64`
  - already used for patched-bundle execution
- `generatedArtifacts`
  - deterministic artifact refs emitted by review/render
- `runtimeHooks`
  - ordered bundled hook references
- `postRenderActions`
  - deterministic, reviewable actions derived from the source kind

These fields must stay declarative. The manifest should describe the approved
bundle and ordered runtime actions, not embed ad hoc imperative controller
logic.

### Review and Approval Requirements

Before any new source kind becomes executable, review must show:

- the patched `topology.yml` diff
- all generated bundle artifacts
- targeted devices
- declared hook points or post-render actions
- rollback evidence that will be captured if execution proceeds

Approval remains explicit and separate from render.

### Rollback Contract

New source kinds must reuse the same rollback model:

- previous deployment config JSON or previous topology bundle reference
- generated artifact references tied to the run
- replay through the same `config-change-run` task type and `netlab-c9s` seam

If a source kind cannot support deterministic rollback evidence, it should not
become executable.

### Acceptance Gate For Widening Scope

Treat a new source kind as eligible for execution only when all of the
following are true:

- it normalizes into a patched bundle, deterministic bundled sidecars, or
  deterministic bundled runtime hooks
- review can display the resulting topology/bundle delta
- execution uses the same `netlab-c9s` worker seam
- rollback uses the same captured deployment-config or bundle replay path
- verification reuses the existing topology-current and node-status evidence
  model

Until then, leaving the source kind out of the executable set is the correct
behavior.
