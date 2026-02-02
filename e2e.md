# Skyforge E2E (Netlab/Clabernetes) Quick Runs

This repo includes an API-driven E2E runner that validates and deploys a small netlab topology per device type, then verifies SSH reachability.

## Prereqs
- Access to the Skyforge URL (default below assumes prod).
- Admin password available via `SKYFORGE_E2E_PASSWORD`, or via `SKYFORGE_SMOKE_PASSWORD`, or via `deploy/skyforge-secrets.yaml` (same logic as the runner).
- Working `kubectl` pointed at the cluster when using `collector_exec` probes:
  - `export KUBECONFIG=skyforge-private/.kubeconfig-skyforge`
- A running per-user collector (Skyforge UI: Collectors) for SSH verification via collector exec.

## Run One Device (Validate + Deploy + SSH)
From `skyforge-private/server`:

```bash
export SKYFORGE_E2E_BASE_URL="https://skyforge.local.forwardnetworks.com"
export SKYFORGE_E2E_DEVICES=nxos
export SKYFORGE_E2E_DEPLOY=true
export SKYFORGE_E2E_DEPLOY_DEVICES=nxos
export SKYFORGE_E2E_SSH_PROBE=true
export SKYFORGE_E2E_SSH_PROBE_MODE=collector_exec

go run ./cmd/e2echeck -run-generated
```

Outputs are written under `skyforge-private/docs/` by default:
- `skyforge-private/docs/e2e-runlog.jsonl`
- `skyforge-private/docs/e2e-reachability-status.json`
- `skyforge-private/docs/e2e-reachability-status.md`

## Notes
- Workspaces created by the E2E runner are deleted automatically at the end of the run (and on Ctrl+C).
- To reuse an existing workspace (no auto-delete), set `SKYFORGE_E2E_WORKSPACE_ID`.

