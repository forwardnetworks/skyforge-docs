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

## Workspace lifecycle
- Create a workspace (no deployments required for smoke).
- Open the workspace list and confirm it appears.
- Delete the workspace and confirm it disappears.

## Optional integration checks
- Git UI: `https://<hostname>/git/`
- NetBox UI: `https://<hostname>/netbox/`
- Nautobot UI: `https://<hostname>/nautobot/`
- API Docs (ReDoc): `https://<hostname>/docs/`
- OpenAPI schema: `https://<hostname>/openapi.json` (should include a `servers` entry with `url: /api/skyforge`)
- API testing: `https://<hostname>/api-testing/` (routes to Yaade on the same hostname)
  - First login uses `admin` / `password`; change the password immediately in Yaade.

If an integration is disabled, remove its health check from
`SKYFORGE_HEALTH_HTTP_CHECKS` so it doesn’t show up as degraded.
