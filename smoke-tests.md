# Smoke tests

These tests validate a minimal deployment without running full end‑to‑end jobs.

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

## Deployment action idempotency smoke (API-level)
```bash
cd components/server
SKYFORGE_BASE_URL="https://<hostname>" \
SKYFORGE_SECRETS_FILE="../../deploy/skyforge-secrets.yaml" \
SKYFORGE_SMOKE_ACTION_CHECK=true \
go run ./cmd/smokecheck
```

This exercises `/api/users/:id/deployments/:deploymentID/action` with
`stop/create/start` and validates idempotency reason behavior.

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
