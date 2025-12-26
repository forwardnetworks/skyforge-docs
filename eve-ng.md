# EVE-NG Integration (Skyforge)

Skyforge supports multiple EVE-NG servers. In k3s, the preferred integration is **SSH-based** (key auth) for health + lab listing, with EVE server selection stored **per Skyforge Project**.

## Configuration (k3s)

1. Create a secrets file (not committed; `secrets/` is gitignored):

   - Path: `secrets/skyforge_eve_servers.json`
   - Format:

     ```json
     {
       "servers": [
         {
           "name": "eve-ng-01",
           "webUrl": "https://__EVE_NG_HOST__/",
           "sshHost": "__EVE_NG_HOST__",
           "sshUser": "root",
           "labsPath": "/opt/unetlab/labs",
           "tmpPath": "/opt/unetlab/tmp"
         }
       ]
     }
     ```

2. Apply/update k8s secrets and roll out:

   - `kubectl apply -k k8s/overlays/k3s-traefik-secrets`
   - `kubectl -n skyforge rollout restart deploy/skyforge-server`

## API

- List configured EVE servers (authenticated):
  - `GET /skyforge-server/eve/servers`

- Health check (public; used by `healthwatch` and the UI):
  - `GET /skyforge-server/health/eve`
  - `GET /skyforge-server/health/eve?full=1` (include per-server detail; can be slower)

- List labs (authenticated, per-user view):
  - `GET /skyforge-server/labs/user?provider=eve-ng&project_id=<semaphoreProjectId>`
  - Fallback (manual override): `GET /skyforge-server/labs/user?provider=eve-ng&eve_server=eve-ng-01`

- List running labs (public):
  - `GET /skyforge-server/labs/running?provider=eve-ng&project_id=<semaphoreProjectId>`
  - Fallback (manual override): `GET /skyforge-server/labs/running?provider=eve-ng&eve_server=eve-ng-01`

- Project lab path (authenticated):
  - `GET /skyforge-server/projects/<projectId>/eve/lab` (returns lab path + existence)
  - `POST /skyforge-server/projects/<projectId>/eve/lab` (creates `/Users/<owner>/<project-slug>.unl` if missing)

## UI

- The Toolchain “EVE-NG Labs” card launches via `GET /labs/?project_id=<semaphoreProjectId>` which redirects to the project’s configured EVE server web UI.
- Set the EVE server on the Projects page (“Set EVE” button), which updates `eveServer` for that project in Postgres.
- Projects use a per-owner lab path: `/Users/<owner>/<project-slug>.unl`. Editors/viewers link to the owner’s lab.
- Use **Show EVE Lab Path** / **Ensure EVE Lab** on the Projects page to view/create the lab file via SSH.

## Notes

- Prefer SSH key auth (no EVE web/API credentials required) by setting:
  - `SKYFORGE_EVE_SSH_KEY_FILE` (k3s uses `/run/secrets/eve-runner-ssh-key`)
  - `SKYFORGE_EVE_SSH_USER` (defaults to `root`)
- The k3s secret for `SKYFORGE_EVE_SSH_KEY_FILE` comes from the local file `secrets/eve_runner_ssh_key` (gitignored) applied via `k8s/overlays/k3s-traefik-secrets`.
- The old EVE API credential fields (`username`/`password`) are still supported as a fallback for environments that require it, but are not recommended for this setup.
- Host reachability check (from the k3s node):
  - `</dev/tcp/10.0.0.10/22` and `</dev/tcp/10.0.0.10/443`
