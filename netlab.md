# Netlab runner (API-based)

Skyforge executes Netlab by calling a lightweight API server on the Netlab host.
The server imports Netlab modules directly (no shell wrapper) and exposes a small
job API.

## API endpoints

- `GET /healthz` → health check.
- `GET /templates?dir=<repo-relative-path>` → list YAML templates.
- `POST /jobs` → start a job.
- `GET /jobs/{id}` → job status.
- `GET /jobs/{id}/log` → streamed stdout/stderr.
- `GET /status` → Netlab status output (`netlab status --all`).

## Job payload fields

- `action`: `up`, `down`, `status`, `create`, or `collect`.
- `user`: username for workspace scoping.
- `project`: project slug.
- `deployment`: deployment name.
- `workspaceRoot`: root path for Netlab workspaces (defaults to `/home/<user>/netlab`).
- `topologyPath`: repo-relative topology path (optional).
- `topologyUrl`: URL to fetch a topology (optional).
- `collectOutput`: output directory for `collect` (optional).
- `collectTar`: tarball path for `collect` (optional).
- `collectCleanup`: `true` to cleanup after collect (optional).
- `cleanup`: `true` to cleanup on `down` (optional).

## Runner (Semaphore)

Skyforge’s Semaphore template calls `netlab/job/run_netlab_api.py`, which:

1) Posts a job to the Netlab API.
2) Polls job status.
3) Streams logs back into the Semaphore task output.

Key environment variables:

- `NETLAB_API_URL` (e.g. `https://<netlab-host>:8090`)
- `NETLAB_ACTION` (`up`, `down`, `status`, `collect`)
- `NETLAB_USER`, `NETLAB_PROJECT`, `NETLAB_DEPLOYMENT`
- `NETLAB_WORKSPACE_ROOT` (optional)
- `NETLAB_TOPOLOGY` or `NETLAB_TOPOLOGY_URL`

## Notes

- The API writes per-job logs under `NETLAB_API_DATA_DIR` (default `/var/lib/skyforge/netlab-api`).
- Use `NETLAB_API_INSECURE=true` if you terminate TLS elsewhere and need to skip cert verification.
