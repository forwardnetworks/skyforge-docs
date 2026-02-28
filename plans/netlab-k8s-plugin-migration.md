# Netlab K8s Plugin Migration (Cleanup + Hard-Cut)

Date: 2026-02-28

## Goal

Move `c9s/netlab` from wrapper-heavy orchestration toward a strict netlab plugin
contract while preserving native Skyforge ownership of lifecycle, policy, and
auditing.

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

## Remaining cleanup before plugin-first rollout

1. Define plugin contract v1 (schema + versioning)
   - plugin-emitted deployment metadata required by Skyforge taskengine
   - strict validation at manifest ingestion

2. Move remaining wrapper glue into plugin outputs
   - device capability/driver hints currently inferred in Go
   - any node behavior currently reconstructed from kind/image where plugin can emit directly

3. Contract-level conformance tests
   - golden manifest tests for success/fail-closed cases
   - taskengine tests for reject-on-missing-required-fields

4. Upstream sync strategy
   - keep `vendor/netlab` fork minimal and replayable
   - document upstream delta and required hooks

## Exit criteria

- Native `c9s/netlab` deploy path consumes only contract-validated plugin output
  for node/config semantics.
- No compatibility code remains for old manifest fields.
- Manual GUI deploy/stop/destroy and Forward sync operate without wrapper-only
  inference paths.
