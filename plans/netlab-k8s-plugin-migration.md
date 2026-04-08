# Netlab K8s Plugin Migration (Cleanup + Hard-Cut)

Date: 2026-02-28

## Goal

Move `kne/netlab` from wrapper-heavy orchestration toward a strict netlab plugin
contract while preserving native Skyforge ownership of lifecycle and auditing.

## Hard requirements

- Netlab-generated artifacts are the only source for node/config behavior.
- No runtime schema fallbacks once a contract version is cut.
- No BYOS fallback behavior in native `kne/netlab` path.
- Keep deployment creation/state transitions in Skyforge APIs/tasks.

## Completed cleanup in this pass

- Removed legacy manifest schema compatibility shims in taskengine:
  - dropped snake_case manifest field fallbacks (`contract_version`,
    `generator_version`, `bundle_sha256`, `netlab_output`).
  - manifest contract now reads canonical fields only.
- Hardened netlab generator runtime to in-cluster-only kube auth (no
  kubeconfig fallback path).
- Stabilized applier tar extraction contract across Python versions with
  explicit tar extraction filter handling.
- Updated docs to reflect plugin-migration direction (no longer framed as
  “maybe later”).
- Added contract v1 schema lock:
  - canonical schema file `internal/taskengine/netlab_kne_manifest.schema.json`
  - generator validates manifest against schema before publish
  - runtime `up` path validates manifest JSON before deploy/apply
  - golden schema fixtures enforce fail-closed behavior in CI tests
- Removed kne/netlab Skyforge-side initial-policy and SSH/auth readiness gating;
  apply sequencing now executes as a netlab runtime phase.
- Removed kne Go-side cEOS bootstrap synthesis and bind rewrites from deploy preparation.
- Removed topology pre-validation patching in taskengine; kne/netlab now validates against
  netlab-generated manifest/device metadata post-`netlab create`.
- Moved native kne Topology CR apply sequencing into netlab runtime bring-up phase
  (`netlab.py up`), so Skyforge taskengine orchestrates jobs and persists state
  while runtime performs CR submit/readiness/apply sequencing.
- Removed Go-side `filesFromConfigMap` synthesis from generator/taskengine path;
  netlab runtime deploy now derives mount layout directly from manifest contract.
- Switched netlab-kne destroy from direct kne task invocation to netlab
  runtime mode (`netlab.py down`) and runtime-owned topology/configmap teardown.
- Removed remaining internal `clabTarball` plumbing from netlab-kne taskengine
  dispatch/deploy metadata path.
- Extended manifest node contract with canonical `forwardType` emitted by runtime
  generator and consumed directly by taskengine graph/status persistence (no
  forward-type derivation at graph-apply time).
- Added strict runtime manifest contract validation in taskengine:
  - JSON decode now fails on unknown fields
  - required contract fields are validated before topology graph/status persistence
  - kne runtime manifest must include netlab k8s plugin metadata (`k8s.contract`, `k8s.provider`)
- Added contract conformance tests (fixtures + Go tests):
  - valid minimal contract case
  - fail-closed checks for missing required fields and unknown fields
- Netlab runtime now reads `k8s` metadata from netlab snapshot output and emits it
  into `manifest.json` for explicit plugin provenance.
- Hardened runtime backend contract to `k8s` only across Skyforge/netlab:
  - manifest schema/validator now reject `docker` backend metadata
  - runtime payload builder no longer emits docker image-pull config
  - kne deploy contract is fail-closed on non-`k8s` runtime backend values
- Removed Docker package dependency from kne launcher image and pinned
  launcher backend resolution to `k8s` in runtime code paths.
- Removed chart/runtime fallback toggles for kne runtime mode:
  - `SKYFORGE_KNE_RUNTIME_MODE` env wiring removed from worker chart
  - chart value knob `skyforge.netlab.kneRuntimeMode` removed
  - docs now reflect k8s-only runtime contract (no docker fallback toggle)

## Remaining cleanup before plugin-first rollout

1. Move remaining wrapper glue into plugin outputs
   - device capability/driver hints currently inferred in Go
   - any node behavior currently reconstructed from kind/image where plugin can emit directly

2. Contract-level conformance tests
   - golden manifest tests for success/fail-closed cases
   - taskengine tests for reject-on-missing-required-fields

3. Upstream sync strategy
   - keep `vendor/netlab` fork minimal and replayable
   - document upstream delta and required hooks

## Exit criteria

- Native `kne/netlab` deploy path consumes only contract-validated plugin output
  for node/config semantics.
- No compatibility code remains for old manifest fields.
- Manual GUI deploy/stop/destroy and Forward sync operate without wrapper-only
  inference paths.
