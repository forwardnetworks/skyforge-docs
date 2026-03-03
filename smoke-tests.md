# Smoke tests

These tests validate a minimal deployment without running full end‑to‑end jobs.

## Automated post-deploy smoke
```bash
SKYFORGE_BASE_URL="https://<hostname>" \
SKYFORGE_SMOKE_INSECURE_TLS=true \
./scripts/post-deploy-smoke.sh
```

Optional authenticated deploy+forward smoke (action-path checks; preflight
coverage is optional):
```bash
SKYFORGE_BASE_URL="https://<hostname>" \
SKYFORGE_SMOKE_USERNAME="admin" \
SKYFORGE_SMOKE_PASSWORD="<password>" \
SKYFORGE_SMOKE_RUN_ACTION_CHECK=true \
SKYFORGE_SMOKE_FWD_PROFILE="<fwd-cli-profile>" \
./scripts/post-deploy-smoke.sh
```

When credentials are provided, the script also records run results to:
- `POST /api/admin/smoke-runs`

You can disable/require reporting behavior with:
- `SKYFORGE_SMOKE_REPORT_ENABLED=true|false`
- `SKYFORGE_SMOKE_REPORT_REQUIRED=true|false`

## Cluster health
```bash
kubectl -n skyforge get pods
```

## API health
```bash
kubectl -n skyforge run skyforge-smoke --rm -i --restart=Never \
  --image=curlimages/curl -- sh -c \
  "curl -fsS http://skyforge-server:8085/api/health"
```

## UI health
- Open `https://<hostname>/`.
- Verify the platform status loads.
- Confirm the toolchain links that you enabled respond.

## Auth flow
- Sign in.
- Verify the dashboard loads and the user menu shows your name.

## User-scoped lifecycle
- Open Deployments and verify the page loads without any scope chooser; it should default to your single user scope.
- Create a deployment.
- Delete the deployment and confirm it disappears.

## Deployment and Forward smoke (API-level)
```bash
cd ../skyforge-cli
SKYFORGE_BASE_URL="https://<hostname>" \
SKYFORGE_CLI_USERNAME="admin" \
SKYFORGE_CLI_PASSWORD="<password>" \
go run ./cmd/skyforge-cli --profile smoke --insecure \
  auth login --password "$SKYFORGE_CLI_PASSWORD"
go run ./cmd/skyforge-cli --profile smoke --insecure \
  smoke suite --scope deploy-forward --timeout 60s --fwd-profile "<fwd-cli-profile>"
```

This exercises:
- `/api/users/:id/deployments/:deploymentID/action`
- `/api/users/:id/deployments/:deploymentID/forward/sync`

plus run diagnostics (`/api/runs/:id/output`, `/events`, `/lifecycle`), deployment artifacts,
and optional `fwd-cli` checks for latest snapshot + device inventory.

Pin EVPN template + strict checks:

```bash
go run ./cmd/skyforge-cli --profile smoke --insecure \
  smoke suite \
  --scope deploy-forward \
  --template EVPN/ebgp/topology.yml \
  --fwd-profile "<fwd-cli-profile>" \
  --strict-forward \
  --assert-config \
  --assert-stanzas auto \
  --debug-artifacts
```

Stress reliability run:

```bash
go run ./cmd/skyforge-cli --profile smoke --insecure \
  smoke stress \
  --scope deploy-forward \
  --template EVPN/ebgp/topology.yml \
  --fwd-profile "<fwd-cli-profile>" \
  --cycles 10 \
  --stop-on-failure
```

## Optional integration checks
- Git UI: `https://<hostname>/api/gitea/public`
- NetBox UI: `https://<hostname>/netbox/`
- Nautobot UI: `https://<hostname>/nautobot/`
- API docs (ReDoc): `https://<hostname>/redoc/`
- OpenAPI schema: `https://<hostname>/openapi.json` (should include a `servers` entry with `url: /api/skyforge`)
- API testing: `https://<hostname>/api-testing/` (routes to Yaade on the same hostname)
  - First login uses `admin` / `password`; change the password immediately in Yaade.

If an integration is disabled, remove its health check from
`SKYFORGE_HEALTH_HTTP_CHECKS` so it doesn’t show up as degraded.
