# Iterative SNMPv2 + UI Certification Loop

This runbook executes iterative certification for in-cluster Forward only:

1. Per-NOS SNMPv2 + deep Forward verification (`e2echeck` matrix)
2. UI deployment verification per NOS (Playwright)
3. Final full-mesh gate once per-NOS/UI are fully green

## Policy defaults

- Forward target: in-cluster only
- Cleanup: keep fails / clean passes (`SKYFORGE_E2E_CLEANUP_MODE=pass-only`)
- Retry budget: 3 iterations
- Full-mesh runs only after per-NOS/UI pass

## Required environment

- `SKYFORGE_E2E_BASE_URL`
- `SKYFORGE_UI_E2E_BASE_URL`
- `SKYFORGE_UI_E2E_API_URL`
- `SKYFORGE_UI_E2E_ADMIN_TOKEN`
- `SKYFORGE_UI_E2E_REQUIRE_INAPP=true`
- `SKYFORGE_UI_E2E_INAPP_FORWARD_URL=http://fwd-appserver.forward.svc.cluster.local:8080`
- `SKYFORGE_UI_E2E_INAPP_FORWARD_USERNAME`
- `SKYFORGE_UI_E2E_INAPP_FORWARD_PASSWORD`
- `SKYFORGE_E2E_FORWARD_BASE_URL` (must not be `fwd.app` unless override is explicit)
- `SKYFORGE_E2E_FORWARD_USERNAME`
- `SKYFORGE_E2E_FORWARD_PASSWORD`

## Run

From repo root:

```bash
SKYFORGE_E2E_CLEANUP_MODE=pass-only \
SKYFORGE_E2E_MAX_ITERATIONS=3 \
make e2e-cert-loop
```

Optional:

- `SKYFORGE_E2E_DEVICES` to limit initial device set
- `SKYFORGE_E2E_SKIP_FULLMESH=true` for debug-only loop runs
- `SKYFORGE_E2E_STATUS_ROOT=artifacts/e2e-cert/<custom-run-id>`

## Artifacts

Written under `artifacts/e2e-cert/<run-id>/`:

- `iteration-N/api/...`
- `iteration-N/ui/...`
- `iteration-N/summary.json`
- `iteration-N/summary.md`
- `final-fullmesh/...`
- `cert-gate-summary.json`
- `cert-gate-summary.md`
