# Composite Deployments (Scaffold v1)

Skyforge treats each deployment as a single engine today (`terraform`, `netlab`, `containerlab`).
This scaffold defines the **next contract** for chaining stages (for example `terraform -> netlab`) with explicit variable handoff and no ad-hoc glue.

## Scope

This document defines planning and contract semantics only.
Execution wiring is tracked separately.

## Terraform Target Model

Terraform stages are no longer limited to public-cloud-only semantics.

- `cloud`/target values such as `aws`, `azure`, and `gcp` keep current auth bootstrap behavior.
- Non-cloud targets (for example `nsxt`, `kubevirt`, `vsphere`, `onprem`) are valid when
  stage/template authors provide explicit `templatesDir` and required provider credentials as environment variables.
- The execution contract stays Terraform-native: Skyforge orchestrates `init/plan/apply/destroy`,
  and provider behavior remains inside Terraform templates/modules.
- Runtime guardrail: non-cloud targets fail closed when `templatesDir` is missing.

This is the foundation for multi-topology workflows where Terraform can provision
on-prem/virtualization infrastructure that netlab/containerlab stages consume via explicit bindings.

### KubeVirt-First On-Prem Pattern

For on-prem lab expansion, prefer a Terraform target profile like `kubevirt` with:

- explicit `templatesDir` (for example `onprem/terraform/kubevirt`)
- provider-native auth/env vars passed through deployment environment
- Terraform outputs for downstream stage bindings (`vm_mgmt_ips`, `service_endpoints`, `edge_peer_ips`)

This keeps Skyforge orchestration generic while letting Terraform own virtualization specifics.

## Contract Goals

- One deployment intent, multiple ordered stages.
- Explicit output-to-input handoff (for VPN/tunnel values and similar runtime facts).
- Deterministic stage graph validation before execution.
- Native provider seams only (`terraform`, `netlab`, `containerlab`, `baremetal`).

## Composite Plan Contract

A composite plan has:

- `stages[]`: ordered logical units with explicit `id`, `provider`, `action`, and `dependsOn`.
- `bindings[]`: variable handoff edges from prior stage outputs into later stage inputs.
- `inputs`: user/admin supplied values available at plan start.
- `outputs`: declared stage outputs promoted as deployment outputs.

### Provider Set (v1 scaffold)

- `terraform`
- `netlab`
- `containerlab`
- `baremetal`

### Action Set (v1 scaffold)

- `terraform`: `plan`, `apply`, `destroy`
- `netlab`: `up`, `down`, `validate`
- `containerlab`: `deploy`, `destroy`, `validate`
- `baremetal`: `reserve`, `configure`, `release`, `validate`

## Variable Handoff Model

Bindings are explicit edges:

- Source: `fromStageId + fromOutput`
- Target: `toStageId + toInput`
- Optional transform: `as` (rename only in v1)
- Sensitivity: `sensitive=true` marks secret output propagation

Example handoff for VPN-style workflow:

1. `terraform.apply` outputs:
- `aws.vpn.public_ip`
- `aws.vpn.psk`
- `aws.vpc.cidr`

2. `netlab.up` inputs via bindings:
- `vpn_peer_ip <- aws.vpn.public_ip`
- `vpn_psk <- aws.vpn.psk` (sensitive)
- `remote_cidr <- aws.vpc.cidr`

## Validation Rules

A plan is valid only when:

- All stage IDs are unique.
- Every `dependsOn` target exists.
- Stage graph is acyclic.
- Every binding source stage/output exists and precedes target stage.
- Every binding target stage/input exists.
- Provider/action pair is allowed.

## Bare Metal Integration (Scaffold)

`baremetal` stages are orchestration seams, not hardware-specific drivers.

v1 assumptions:

- Reservation/configuration adapters stay behind provider-native contracts.
- Output contract examples: `mgmt_ip`, `hostname`, `asset_id`, `reservation_id`.
- Inputs can be sourced from `terraform` outputs or operator-provided values.

## Execution Semantics (Future)

- Stage transitions: `pending -> running -> success|failed|skipped`.
- First failure stops downstream stages unless marked optional.
- Sensitive bound values are redacted in logs/events.

## API Scaffold

Server exposes a preview endpoint that validates and normalizes a composite plan:

- `POST /api/users/:id/composite/plan/preview`
- No execution side effects.
- Returns normalized stage order, resolved bindings, and warnings.

Server also supports persisted-plan execution:

- `POST /api/users/:id/composite/plans/:planID/runs`
- Enqueues a `composite-run` task with stage-by-stage execution and binding handoff.
- Current execution support: `terraform`, `netlab`, and `baremetal` stages.
- `baremetal` stages can resolve user-saved Fixia connections via `server: "user:<server-id>"`.

## Checklist

- [x] Define provider/action enums for composite plan preview.
- [x] Define stage/binding/input/output request schema.
- [x] Implement server-side preview validation (DAG + binding checks).
- [x] Add persistent composite deployment spec storage.
  - Added user-scope composite plan CRUD API and backing DB table (`sf_composite_plans`).
  - API paths:
    - `GET /api/users/:id/composite/plans`
    - `POST /api/users/:id/composite/plans`
    - `GET /api/users/:id/composite/plans/:planID`
    - `PUT /api/users/:id/composite/plans/:planID`
    - `DELETE /api/users/:id/composite/plans/:planID`
- [x] Add execution runner with stage state transitions.
- [x] Add portal authoring UI for stage graph + bindings.
  - Added `/dashboard/deployments/composite` with user-scope plan authoring,
    preview, save/update/delete, and run enqueue.
- [x] Add end-to-end `terraform -> netlab` reference blueprint.
  - Reference payload: `components/docs/examples/composite-plan-terraform-netlab.json`
- [x] Add `baremetal -> netlab` reference blueprint.
  - Reference payload: `components/docs/examples/composite-plan-baremetal-netlab.json`
- [x] Integrate baremetal server settings with Fixia user-scope credentials.
  - Added user-scope Fixia server CRUD and taskengine resolver for `server: "user:<id>"`.
- [x] Add targeted composite portal UI tests.
  - Added `components/portal/src/components/deployments/composite-plans-page-content.test.tsx`.
- [x] Add composite run history/status view in portal.
  - Composite page now lists recent composite runs from `/api/runs` and tracks selected run state.
- [x] Add stage-level evidence surfacing for composite execution.
  - Composite page now renders `composite.stage.*` lifecycle events (running/success/failed) with provider/action/output summary.
- [ ] Backlog: add first-class Terraform `kubevirt` provider profile + reference module for VM lifecycle stages.
