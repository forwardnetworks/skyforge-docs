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

## Project lifecycle
- Create a project (no deployments required for smoke).
- Open the project list and confirm it appears.
- Delete the project and confirm it disappears.

## Optional integration checks
- Git UI: `https://<hostname>/git/`
- NetBox UI: `https://<hostname>/netbox/`
- Nautobot UI: `https://<hostname>/nautobot/`
- Swagger UI: `https://<hostname>/swagger/`
- Swagger schema: `https://<hostname>/swagger/openapi.json` (should include a `servers` entry with `url: /api/skyforge`)
- API testing: `https://<hostname>/api-testing/` (switches to Hoppscotch on the same hostname)
  - Exit: `https://<hostname>/api-testing/exit`
  - Note: while API Testing is enabled, Hoppscotch expects `/` and can mask the portal root; use `/status` or `/dashboard/home` to reach Skyforge, or exit API Testing.

If an integration is disabled, remove its health check from
`SKYFORGE_HEALTH_HTTP_CHECKS` so it doesn’t show up as degraded.
