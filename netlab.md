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

- `action`: `up`, `create`, `restart`, `down`, `collect`, `status` (plus optional `destroy`).
- `user`: username for workspace scoping.
- `workspace`: workspace slug.
- `deployment`: deployment name.
- `workspaceRoot`: root path for Netlab workspaces (defaults to `/home/<user>/netlab`).
- `plugin`: optional Netlab plugin name (for example `multilab`).
- `multilabId`: optional multilab ID for the `multilab` plugin.
- `stateRoot`: optional state root for external state sharing.
- `topologyPath`: repo-relative topology path (optional).
- `topologyUrl`: URL to fetch a topology (optional).
- `collectOutput`: output directory for `collect` (optional).
- `collectTar`: tarball path for `collect` (optional).
- `collectCleanup`: `true` to cleanup after collect (optional).
- `cleanup`: `true` to cleanup on `down` (optional).
- `environment`: optional environment variables to inject into the Netlab run (`KEY=value`).

## Runner (native)

Skyforge launches Netlab runs directly:

1) Posts a job to the Netlab API.
2) Polls job status.
3) Streams logs into the Skyforge task output.

## Notes

- The API writes per-job logs under `NETLAB_API_DATA_DIR` (default `/var/lib/skyforge/netlab-api`).
- Use `NETLAB_API_INSECURE=true` if you terminate TLS elsewhere and need to skip cert verification.
- The `multilab` plugin requires each instance run in a unique working directory; Skyforge uses `/home/<user>/netlab/<workspace>/<deployment>` by default.
- If template files or topology YAML are newer than the snapshot, the API clears the snapshot/lock and regenerates the lab before running `up`.
- Netlab 26.01+ removes Ansible-based template rendering. Avoid Ansible-only Jinja2 filters in templates and prefer native Netlab filters.
- Template vars updated in Netlab 26.01+: `clab_files` → `node_files`, `hosts` → `host_addrs` (legacy `hosts` still works for now).

## Netlab defaults on the runner
Use Netlab’s system defaults to avoid editing templates just to pin a common image.

Example: set EOS to default to `ceos:4.35.1F` in `/etc/netlab/defaults.yml` on the Netlab runner:
```yaml
defaults:
  device: eos
  eos:
    image: ceos:4.35.1F
```

See https://netlab.tools/defaults/ for additional options.
