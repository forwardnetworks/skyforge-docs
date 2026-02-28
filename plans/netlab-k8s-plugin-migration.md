# Netlab K8s Plugin Migration (Cleanup + Hard-Cut)

Date: 2026-02-28

## Goal

Move `c9s/netlab` from wrapper-heavy orchestration toward a strict netlab plugin
contract while preserving native Skyforge ownership of lifecycle and auditing.

## Hard requirements

- Netlab-generated artifacts are the only source for node/config behavior.
- No runtime schema fallbacks once a contract version is cut.
- No BYOS fallback behavior in native `c9s/netlab` path.
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
  - canonical schema file `internal/taskengine/netlab_c9s_manifest.schema.json`
  - generator validates manifest against schema before publish
  - taskengine validates incoming manifest JSON against schema before unmarshal
  - golden schema fixtures enforce fail-closed behavior in CI tests
- Removed c9s/netlab Skyforge-side initial-policy and SSH/auth readiness gating;
  apply sequencing now executes as a netlab runtime phase.
- Removed c9s Go-side cEOS bootstrap synthesis and bind rewrites from deploy preparation.
- Removed topology pre-validation patching in taskengine; c9s/netlab now validates against
  netlab-generated manifest/device metadata post-`netlab create`.

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

- Native `c9s/netlab` deploy path consumes only contract-validated plugin output
  for node/config semantics.
- No compatibility code remains for old manifest fields.
- Manual GUI deploy/stop/destroy and Forward sync operate without wrapper-only
  inference paths.
