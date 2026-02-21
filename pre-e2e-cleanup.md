# Pre-E2E cleanup (recommended)

These steps keep E2E runs deterministic so failures are easier to diagnose.

## 0) Ensure the portal is reachable
- Confirm you can reach the portal at `https://<hostname>/status` (unauthenticated) or `https://<hostname>/dashboard/home` (authenticated)

## 1) Pick a single “test user”
- Use a consistent username for repeatable E2E runs.
- Reset user-owned resources before each run.

## 2) Clean up in Skyforge UI
- Delete any deployments for the test user (netlab/eve-ng/terraform).
- Confirm the deployments list is empty for that user.

## 2b) Dev-only: purge a user (reset “first login”)
If you need to rerun the full onboarding flow for a user (Gitea provisioning, default repo setup, etc),
Skyforge exposes an admin-only purge endpoint.

### Option A: use the helper CLI (recommended)
This logs in as the shared admin user and calls the purge endpoint.

```bash
cd skyforge-private/server
go run ./cmd/purgeuser <username>
```

Config (optional):
- `SKYFORGE_BASE_URL` (default: `https://skyforge.local.forwardnetworks.com`)
- `SKYFORGE_ADMIN_USERNAME` (default: `skyforge`)
- `SKYFORGE_ADMIN_PASSWORD` (preferred) or `SKYFORGE_SECRETS_FILE` (defaults to `../deploy/skyforge-secrets.yaml`)

### Option B: call the API directly
Backend endpoint (Encore): `POST /api/admin/users/purge`

Public URL behind the Skyforge reverse proxy:
`POST https://<hostname>/api/skyforge/api/admin/users/purge`

Body:
```json
{"username":"<username>","confirm":"<username>"}
```

## 3) Verify there are no stale tasks
- Open the Skyforge runs panel and confirm there are no long-running tasks for the test user.

## 4) Verify runner-side state (EVE hosts)
If a prior run left state behind (e.g. a failed job), clean the user directory on the relevant EVE host before rerunning.

## 5) Cluster sanity (kubectl only)
Run `skyforge-private/docs/post-install-verify.md` before starting E2E.
