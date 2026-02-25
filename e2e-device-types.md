# Device-type E2E tests (Netlab + Containerlab)

This doc describes the **device-type** end-to-end tests implemented in `components/server/cmd/e2echeck`.

Goal: quickly answer **“do the device types we ship actually work?”** (template validates, and optionally deploys + accepts SSH).

## What’s covered

### Default scope: onboarded device types

By default, the E2E matrix targets a curated list of “onboarded” device types (what Skyforge exposes in the UI / what we expect to work in-cluster).

- Use `SKYFORGE_E2E_DEVICE_SET=all` to instead generate tests from the upstream Netlab catalog (`internal/taskengine/netlab_device_defaults.json`).
- `vsrx` is explicitly excluded (out of scope).
- Onboarded hard-gate set: `arubacx,asav,cumulus,dellos10,eos,fortios,iol,iosxr,linux,nxos,sros,vjunos-router,vjunos-switch,vmx,vptx`.

### Default depth: validate-only

By default the matrix contains **only `netlab_validate` tests**. Deploy tests are **opt-in** because they are slow.

- Enable in-cluster deploy + SSH probe with `SKYFORGE_E2E_DEPLOY=true`.
- Limit which device types are deployed with `SKYFORGE_E2E_DEPLOY_DEVICES=...`.

### SNMPv2 hard-cut gates

- Per-NOS individual templates: `make e2e-snmpv2-nos`
- Full-mesh release baseline: `make e2e-baseline-fullmesh`
- Combined release gate: `make e2e-release-gate`

Both gates require Forward deep verification and fail when any non-linux node is not SNMPv2-enabled.

## Running locally against Skyforge (in-cluster)

From `components/server`:

```bash
go run ./cmd/e2echeck --generate-matrix > /tmp/skyforge-e2e-matrix.json
```

### Validate device types (fast)

```bash
export SKYFORGE_E2E_DEPLOY=false
go run ./cmd/e2echeck --run-generated
```

### Deploy + SSH probe (slow)

```bash
export SKYFORGE_E2E_DEPLOY=true
export SKYFORGE_E2E_DEPLOY_DEVICES=eos,iol,iol
go run ./cmd/e2echeck --run-generated
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

## BYOS runners (netlab.local.forwardnetworks.com)

Enable BYOS tests (Netlab + Containerlab) with:

```bash
export SKYFORGE_E2E_BYOS=true
export SKYFORGE_E2E_BYOS_NETLAB_API_URL=https://netlab.local.forwardnetworks.com/netlab
```

The E2E runner will configure the user’s Netlab server list (single user scope) via the Skyforge API before launching a BYOS deployment.
