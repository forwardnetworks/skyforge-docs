# Device-type E2E tests (Netlab + Containerlab)

This doc describes the **device-type** end-to-end tests implemented in `components/server/cmd/e2echeck`.

Goal: quickly answer **“do the device types we ship actually work?”** (template validates, and optionally deploys + accepts SSH).

## What’s covered

### Default scope: onboarded device types

By default, the E2E matrix targets a curated list of “onboarded” device types (what Skyforge exposes in the UI / what we expect to work in-cluster).

- `vsrx` is explicitly excluded (out of scope).
- Onboarded hard-gate set: `arubacx,asav,cumulus,dellos10,eos,fortios,iol,ioll2,iosxr,linux,nxos,sros,vjunos-router,vjunos-switch,vmx,vptx`.

### Execution depth

- Native strict mode runs validate + deploy + SSH probe for the generated onboarded catalog.

### SNMPv2 hard-cut gates

- Per-NOS individual templates: `make e2e-snmpv2-nos`
- Full-mesh release baseline: `make e2e-baseline-fullmesh`
- Combined release gate: `make e2e-release-gate`
- Iterative certification loop (per-NOS + UI + final full-mesh): `make e2e-cert-loop`

Both gates require Forward deep verification and fail when any non-linux node is not SNMPv2-enabled.
The iterative loop uses in-cluster Forward by default and supports
`SKYFORGE_E2E_CLEANUP_MODE=pass-only` to keep failed deployments for triage.
Netlab device readiness defaults are sourced from upstream `vendor/netlab`; run `make test-netlab-defaults-drift` (or `make test-generated-drift`) after updating netlab submodules.
Skyforge now validates topology node `kind`/`image` mappings against generated netlab defaults in **fail-closed** mode. Unknown or alias-only devices are rejected during validate/deploy preflight.

## Running locally against Skyforge (in-cluster)

From `components/server`:

```bash
go run ./cmd/e2echeck --generate-matrix > /tmp/skyforge-e2e-matrix.json
```

### Validate device types (fast)

```bash
go run ./cmd/e2echeck
```

### Deploy + SSH probe (slow)

```bash
go run ./cmd/e2echeck
```

Notes:

- SSH probing for release gates should use API mode:
  - `SKYFORGE_E2E_SSH_PROBE_MODE=api`
  - `SKYFORGE_E2E_REQUIRE_API_PROBE=true`
- Queue and worker health should be enforced in gate runs:
  - `SKYFORGE_E2E_GATE_QUEUE_HEALTH=true`
  - `SKYFORGE_E2E_QUEUE_MAX_AGE_SECONDS=300`
  - `SKYFORGE_E2E_HEARTBEAT_MAX_AGE_SECONDS=120`

## Full NOS certification (hard gate)

Run from repo root:

```bash
make e2e-nos-full
```

This performs:

- `scripts/e2e-netlab-nos-preflight.sh` (tools + cluster + image ref checks)
- `scripts/e2e-netlab-nos-full.sh` (sharded deploy+SSH runs across all onboarded NOS)
- `scripts/e2e-netlab-nos-report.sh` (merged pass/fail summary)

Artifacts are written under `artifacts/e2e-nos/<run-id>/`.

## Notes

- `e2echeck` is strict native mode and always uses generated matrix data from `internal/taskengine/netlab_device_defaults.json`.
- Device/template/matrix filter env vars are intentionally rejected to avoid drift from the native source of truth.
