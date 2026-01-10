# Pre-E2E cleanup (recommended)

These steps keep E2E runs deterministic so failures are easier to diagnose.

## 0) Ensure the portal is reachable
- Confirm you can reach the portal at `https://<hostname>/status` (unauthenticated) or `https://<hostname>/dashboard/home` (authenticated)

## 1) Pick a single “test workspace”
- Use a consistent slug (example: `e2e-test`).
- Always delete and recreate it for each E2E run.

## 2) Clean up in Skyforge UI
- Delete any deployments in the test workspace (netlab/labpp/terraform).
- Delete the test workspace itself.
- Confirm it’s gone from the Workspaces list.

## 3) Verify there are no stale tasks
- Open the Skyforge runs panel and confirm there are no long-running tasks for the test workspace.

## 4) Verify runner-side state (EVE hosts)
If a prior run left state behind (e.g. a failed job), clean the workspace directory on the relevant EVE host before rerunning.

## 5) Cluster sanity (kubectl only)
Run `skyforge-private/docs/post-install-verify.md` before starting E2E.
