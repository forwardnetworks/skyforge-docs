# E2E checklist (UI → runners)

This checklist is meant to be run **after** a deploy (Helm) when you want a single end-to-end validation pass.

## Prereqs

- Skyforge is reachable at `https://<skyforge-hostname>/`.
- `https://<skyforge-hostname>/status/summary` returns `status=ok` (or expected degraded state).
- (Legacy) `https://<skyforge-hostname>/data/platform-health.json` is still available (served from live checks).
- Runner secrets exist and are non-empty:
  - `eve-runner-ssh-key` (`eve-runner-ssh-key` key)
  - `netlab-runner-rsa` (`netlab-runner-rsa` key)
  - `skyforge-eve-servers` (`skyforge-eve-servers` key)
  - `skyforge-netlab-servers` (`skyforge-netlab-servers` key) or (fallback) EVE servers are present so Netlab servers can be derived.

## Auth + dashboard

- Sign in via LDAP as a non-admin user.
- Confirm sidebar has only the authenticated Coder entry (no “shared” link).
- Confirm DNS link is only visible when authenticated.
- Open `EVE-NG` section and confirm the configured hosts appear.

## User scope + deployments

### Create user scope
- Create a user scope as the non-admin user.

### Netlab deployment (create → up → info → down → destroy → delete)
- Create a Netlab deployment:
  - Pick the Netlab server (required).
  - Pick a template source (blueprints repo or user repo).
  - Pick a template.
- Run actions in order:
  - `Create` (should provision user-scope files without starting lab)
  - `Start` / `Up`
  - `Info` (should show `netlab status` output with IPs/topology)
  - `Stop` / `Down`
  - `Destroy` (should remove user-scope artifacts on the runner)
  - Delete the deployment record in Skyforge
- Confirm logs are readable in the single “Logs” modal.

### Containerlab deployment (create → up → info → down → destroy → delete)
- Create a Containerlab deployment:
  - Pick the Containerlab server (required).
  - Pick a template source (blueprints repo or user repo).
  - Pick a template.
- Run actions in order:
  - `Create`
  - `Start`
  - `Info` (should show containerlab inspect output)
  - `Stop`
  - `Destroy`
  - Delete the deployment record in Skyforge
- Confirm logs are readable in the single “Logs” modal.

### LabPP deployment (create → up → info → down → destroy → delete)
- Create a LabPP deployment:
  - Pick the EVE server (required).
  - Pick a template source + template.
- Run the same action sequence and validate:
- `Info` shows LabPP status and lab path for the selected deployment.
- Use `Sync Forward` on the LabPP info panel to re-push devices into Forward after a run.
  - EVE server selection is honored (deploys to the chosen host).

## Toolchain SSO links

From an authenticated session, click each tool and confirm you land inside the tool without an extra login prompt:

- Git (Gitea)
- NetBox
- Nautobot
- S3 artifact path (`/files`)
- DNS (Technitium; first-time flow may prompt for a Technitium password)
- Swagger UI
- API Testing (Hoppscotch) launches correctly
