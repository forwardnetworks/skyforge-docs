---
harness_kind: active-exec-plan
status: active
legacy_source: components/docs/plans/long-term-architecture-skyforge-netlab-kne.md
converted_at: 2026-04-27
title: Long-Term Architecture: Skyforge + Netlab + KNE
current_truth: verify against current code and environment before execution
---

# Long-Term Architecture: Skyforge + Netlab + KNE

Date: 2026-03-04

## Objective

Move from tactical runtime patches to a stable architecture where:

- Skyforge is a pure orchestrator (lifecycle, tenancy, policy, audit).
- Netlab is source of truth for topology/config generation and apply sequencing.
- KNE is the only Kubernetes runtime for topology execution (no Docker-in-Docker path).

## Hard Principles

1. No Skyforge device/NOS-specific config logic.
2. No runtime fallbacks for deprecated contracts in native mode.
3. No Docker dependency in the native kne runtime path.
4. Netlab defaults/J2 remain the only place for NOS behavior.
5. Runtime artifacts must be queryable from DB/object storage, not ad hoc local files.

## Component Boundaries

### Skyforge (control plane only)

Owns:

- Deployment API and state machine (`create`, `bring-up`, `stop`, `destroy`).
- Task queue fairness, retries, idempotency, and cancellation.
- User scope namespace tenancy and access control.
- Policy gates (quota, lifetime, preflight compatibility).
- Artifact metadata persistence (DB rows + object store pointers).
- Forward sync trigger and status recording.

Does not own:

- Per-device startup/auth/config generation.
- Device readiness semantics beyond generic phase timeouts and task orchestration.
- KNE manifest rewriting for NOS quirks.

### Netlab runtime/plugin (execution planner + config owner)

Owns:

- `netlab create`/`netlab up`/`netlab down` semantics.
- Generated `clab.yml`, `node_files`, `config`, inventory and apply ordering.
- Canonical manifest contract fields consumed by Skyforge and kne.
- K8s plugin validation (DNS-1035, provider contract, runtime backend constraints).

Does not own:

- User tenancy policy and lifecycle APIs.
- Forward credentials and org policy.

### KNE (runtime executor only)

Owns:

- Topology CR reconciliation.
- Pod/service/configmap lifecycle for topology nodes.
- Generic startup file mounts and runtime hooks required by kne semantics.
- Runtime backend implementation (`k8s` only in this mode).

Does not own:

- Netlab template semantics.
- Forward sync semantics.
- Skyforge tenancy and queue policy.

## Runtime Contract (single contract path)

Native deploy path contract is:

1. Skyforge schedules runtime job (`netlab.py up`).
2. Netlab runtime emits validated manifest + artifacts.
3. Netlab runtime applies kne topology and runs apply phase.
4. Skyforge records contract metadata + artifacts and updates deployment phases.
5. Skyforge triggers Forward sync (if enabled).

Implementation note:

- For the supported `family=kne, engine=netlab` path, Skyforge should expose a
  thin execution-backend adapter with four responsibilities:
  - `Submit`
  - `Observe`
  - `Access`
  - `Cleanup`
- This adapter exists to keep Skyforge in the control-plane role while KNE
  remains the execution backend. It must not become a second runtime
  reconciler or topology mutator.

Destroy path contract is:

1. Skyforge schedules runtime job (`netlab.py down`).
2. Netlab runtime tears down kne topology and runtime-owned configmaps.
3. Skyforge performs post-destroy state cleanup and artifact finalization.

## IOL/IOLL2 Long-Term Direction

Decision: keep VM vrnetlab support for VM NOS overall, but treat IOL/IOLL2 as native-k8s runtime targets with kne-owned runtime wiring.

Implications:

- No Skyforge IOL-specific bootstrap logic.
- No netlab.py hardcoded IOL networking workarounds.
- KNE must provide generic runtime mount/network semantics needed by IOL startup in Kubernetes.
- Netlab remains source of generated startup/apply artifacts for IOL/IOLL2.

## Data and Artifact Persistence

Use DB for metadata and object storage for large payloads:

- DB:
  - runtime contract summary
  - phase timestamps
  - per-step status
  - forward sync summary
  - topology/node mapping metadata
- Object store:
  - runtime manifest JSON
  - kne topology YAML/JSON
  - netlab output tarball
  - step logs

No new local-file-only runtime outputs.

## Phased Migration Plan

### Phase 1: Contract hardening (immediate)

- Enforce one native runtime backend: `k8s`.
- Remove deprecated/legacy manifest fields from consumers.
- Ensure preflight checks and runtime errors are fail-closed and actionable.

Exit criteria:

- All native runs consume a strict manifest schema with unknown-field rejection.
- No Docker runtime branch reachable for native kne runs.

### Phase 2: Runtime ownership cleanup

- Move remaining NOS runtime quirks out of Skyforge.
- Keep kne runtime behavior generic and upstream-compatible.
- Keep netlab plugin as source for topology/provider validation rules.

Exit criteria:

- Skyforge deployment task code has no NOS-kind branching.
- Netlab/kne own all startup/apply runtime behaviors.

### Phase 3: Lifecycle and UX consistency

- Tighten create/bring-up/destroy idempotency so double-trigger races are impossible.
- Ensure deployment status model reflects queued/running/completed consistently in UI.
- Add debug toggles as explicit deployment runtime options, persisted in DB.

Exit criteria:

- Repeated user clicks cannot enqueue conflicting actions.
- Task and deployment state are always convergent and observable.

### Phase 4: Verification and upstream readiness

- Build replayable delta docs for `vendor/netlab` and `vendor/kne`.
- Keep Skyforge-specific behavior out of upstreamable runtime code.
- Validate representative templates (EVPN + VM mix) end-to-end.

Exit criteria:

- Minimal, documented fork deltas.
- Stable E2E pass set with Forward sync and device config verification.

## Immediate Next Execution Sequence

1. Finish removing remaining native-path NOS-specific logic from Skyforge taskengine.
2. Keep IOL/IOLL2 runtime fixes in kne/netlab layers only; avoid Skyforge patches.
3. Close deployment action race conditions (`create` vs `bring-up`) with strict idempotent guards.
4. Validate EVPN and IOL/IOLL2 template runs against this contract before adding new features.
