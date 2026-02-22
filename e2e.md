# Skyforge E2E (Netlab/Clabernetes) Quick Runs

This repo includes an API-driven E2E runner that validates and deploys a small netlab topology per device type, then verifies SSH reachability.

## Prereqs
- Access to the Skyforge URL (default below assumes prod).
- Admin password available via `SKYFORGE_E2E_PASSWORD`, or via `SKYFORGE_SMOKE_PASSWORD`, or via `deploy/skyforge-secrets.yaml` (same logic as the runner).
- Working `kubectl` pointed at the cluster when using `collector_exec` probes:
  - `export KUBECONFIG=.kubeconfig-skyforge`
- A running per-user collector (Skyforge UI: Collectors) for SSH verification via collector exec.

## Run One Device (Validate + Deploy + SSH)
From `components/server`:

```bash
export SKYFORGE_E2E_BASE_URL="https://skyforge.local.forwardnetworks.com"
export SKYFORGE_E2E_DEVICES=nxos
export SKYFORGE_E2E_DEPLOY=true
export SKYFORGE_E2E_DEPLOY_DEVICES=nxos
export SKYFORGE_E2E_SSH_PROBE=true
export SKYFORGE_E2E_SSH_PROBE_MODE=collector_exec

go run ./cmd/e2echeck --run-generated
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
SKYFORGE_E2E_PREPULL=true \
make e2e-nos-full
```

Artifacts and merged reports are written to `artifacts/e2e-nos/<run-id>/`.

## Notes
- User-scope resources created by the E2E runner are deleted automatically at the end of the run (and on Ctrl+C).
- To reuse an existing user scope (no auto-delete), set `SKYFORGE_E2E_SCOPE_ID`.
- IOS-XR deploy validation requires elevated inotify limits on cluster nodes. Use the Helm chart option `skyforge.clabernetes.nodeSysctl.enabled=true` (recommended) or tune host sysctls manually.
- Deployment tasks no longer gate on Forward SSH readiness. Forward sync is a separate task, so baseline deploy E2E validates topology + SSH probe directly.
