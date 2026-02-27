# Skyforge E2E (Netlab/Clabernetes) Quick Runs

This repo includes an API-driven E2E runner that validates and deploys a small netlab topology per device type, then verifies SSH reachability.

## Prereqs
- Access to the Skyforge URL (default below assumes prod).
- Admin password available via `SKYFORGE_E2E_PASSWORD`, or via `SKYFORGE_SMOKE_PASSWORD`, or via `deploy/skyforge-secrets.yaml` (same logic as the runner).
- API probe mode (`SKYFORGE_E2E_SSH_PROBE_MODE=api`) for release gates; this avoids local kubecontext dependencies.

## Run Strict Native Matrix (Validate + Deploy + SSH)
From `components/server`:

```bash
export SKYFORGE_E2E_BASE_URL="https://skyforge.local.forwardnetworks.com"
export SKYFORGE_E2E_SSH_PROBE_MODE=api
export SKYFORGE_E2E_REQUIRE_API_PROBE=true
export SKYFORGE_E2E_GATE_QUEUE_HEALTH=true

go run ./cmd/e2echeck
```

Outputs are written under `components/docs/` by default:
- `components/docs/e2e-runlog.jsonl`
- `components/docs/e2e-reachability-status.json`
- `components/docs/e2e-reachability-status.md`

## Full onboarded NOS run

From repo root:

```bash
make e2e-nos-full
```

Optional:

```bash
SKYFORGE_E2E_BASE_URL="https://skyforge.local.forwardnetworks.com" \
SKYFORGE_E2E_SSH_PROBE_MODE=api \
SKYFORGE_E2E_REQUIRE_API_PROBE=true \
SKYFORGE_E2E_GATE_QUEUE_HEALTH=true \
SKYFORGE_E2E_PREPULL=true \
make e2e-nos-full
```

Artifacts and merged reports are written to `artifacts/e2e-nos/<run-id>/`.

## Release baseline gates (staged SNMPv2)

Run from repo root:

```bash
make e2e-release-gate
```

This runs:

- `make e2e-snmpv2-nos` (safe-set SNMPv2 deep verify; default devices: `eos,vmx`)
- `make e2e-bringup-other-nos` (bringup-only + SSH + Forward sync for the remaining NOS)

Both targets use `e2echeck`; deploy/SSH timeouts are derived from
the netlab device catalog metadata (`netlab_check_retries` / `netlab_check_delay`)
instead of static per-device timeout tables.
The e2e harness now fails closed if the catalog cannot be loaded, to prevent
falling back to stale hardcoded device behavior.

Override safe-set devices when needed:

```bash
SKYFORGE_E2E_SNMPV2_SAFE_DEVICES="eos,vmx" make e2e-snmpv2-nos
```

## Iterative SNMPv2 + UI certification loop

Run from repo root:

```bash
SKYFORGE_E2E_CLEANUP_MODE=pass-only \
SKYFORGE_E2E_MAX_ITERATIONS=3 \
make e2e-cert-loop
```

This flow runs SNMPv2 + UI checks for the safe device set in iterative loops,
narrows to failed devices in each retry, then runs one final full-mesh gate.
By default, the loop starts with `eos,vmx`.

See `components/docs/e2e-cert-loop.md` for required environment and artifact layout.

Required Forward env vars for deep verify:

- `SKYFORGE_E2E_FORWARD_BASE_URL`
- `SKYFORGE_E2E_FORWARD_USERNAME`
- `SKYFORGE_E2E_FORWARD_PASSWORD`

## Notes
- User-scope resources created by the E2E runner are deleted automatically at the end of the run (and on Ctrl+C).
- Deployment cleanup mode can be controlled with:
  - `SKYFORGE_E2E_CLEANUP_MODE=all|pass-only|none`
  - `all`: always destroy
  - `pass-only`: destroy successful deployments only
  - `none`: never destroy
- To reuse an existing user scope (no auto-delete), set `SKYFORGE_E2E_SCOPE_ID`.
- Queue health gate defaults:
  - `SKYFORGE_E2E_GATE_QUEUE_HEALTH=true`
  - `SKYFORGE_E2E_QUEUE_MAX_AGE_SECONDS=300`
  - `SKYFORGE_E2E_HEARTBEAT_MAX_AGE_SECONDS=120`
- IOS-XR deploy validation requires elevated inotify limits on cluster nodes. Use the Helm chart option `skyforge.clabernetes.nodeSysctl.enabled=true` (recommended) or tune host sysctls manually.
- Deployment tasks no longer gate on Forward SSH readiness. Forward sync is a separate task, so baseline deploy E2E validates topology + SSH probe directly.
