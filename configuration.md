# Configuration quick reference

Skyforge uses typed Encore config (`ENCORE_CFG_SKYFORGE`, `ENCORE_CFG_WORKER`) plus runtime secrets.
For k3s deployments, configure:
- values: `deploy/skyforge-values.yaml`
- secrets: `deploy/skyforge-secrets.yaml` (local-only)

## Edition
- `skyforge.edition`
  - `enterprise` (default): Forward-enabled deployments supported
  - `oss`: Forward integrations are disabled in generated config
  - `oss` cannot be combined with `skyforge.forwardCluster.enabled=true`

## Core host settings
- `skyforge.hostname`
- `skyforge.domain`
- `skyforge.publicUrl`
- `skyforge.adminUsers`

## Required secrets (minimum)
Populate in `deploy/skyforge-secrets.yaml` under `secrets.items`:
- `skyforge-session-secret.skyforge-session-secret`
- `skyforge-admin-shared.password`
- `db-skyforge-server-password.db-skyforge-server-password`
- `object-storage-root-user.object-storage-root-user`
- `object-storage-root-password.object-storage-root-password`
- `proxy-tls.tls.crt`
- `proxy-tls.tls.key`

## Integration endpoints
- `skyforge.gitea.url`
- `skyforge.gitea.apiUrl`
- `skyforge.netboxUrl` (optional)
- `skyforge.nautobotUrl` (optional)
- `skyforge.objectStorage.endpoint`
- `skyforge.objectStorage.useSsl`

## Object storage
- In-cluster default: `skyforge.s3gw.enabled=true` and `skyforge.objectStorage.endpoint=s3gw:7480`.
- External S3: set `skyforge.s3gw.enabled=false` and point `skyforge.objectStorage.endpoint` to external host:port.

## Auth modes
- Skyforge browser auth is selected with `skyforge.auth.mode`.
- Dev / OSS baseline: `skyforge.auth.mode=local`
  - Browser login uses `/login/local` + `POST /api/login`
  - Shared bootstrap password source: `skyforge-admin-shared.password`
- Prod baseline: `skyforge.auth.mode=oidc`
  - Browser login uses `GET /api/auth/oidc/login`
  - Supported OIDC topology is `Skyforge -> Dex -> IdP`
  - For Okta, keep `skyforge.dex.enabled=true`, `skyforge.dex.manageConfig=true`, `skyforge.dex.authMode=oidc`, and populate `skyforge.dex.oidc.*` + `dex-oidc-client-secret`
- On install, hook job `skyforge-auth-runtime-sync` writes `sf_settings` auth keys (`ui_auth_primary_provider`, `ui_oidc_enabled`, `oidc_*`) from chart values/secrets so runtime auth mode stays aligned with declarative config.
- To also run this hook on upgrades, set `skyforge.hooks.authRuntimeSync.runOnUpgrade=true`.
- Dex connector settings (`skyforge.dex.*`) control Dex's upstream identity provider. They do not replace `skyforge.auth.mode`.

## Helm hook semantics
- Bootstrap/reconcile hooks are install-only by default to keep upgrades deterministic:
  - `skyforge.hooks.authRuntimeSync.runOnUpgrade`
  - `skyforge.hooks.dbProvision.runOnUpgrade`
  - `skyforge.hooks.gatewayNodePortsReconcile.runOnUpgrade`
  - `skyforge.hooks.coderAdminBootstrap.runOnUpgrade`
  - `skyforge.hooks.giteaActionsRunnerTokenReconcile.runOnUpgrade`
- Hook jobs expose `backoffLimit` and `activeDeadlineSeconds` under each `skyforge.hooks.*` block.

## Workload priority and reliability
- Optional priority class generation:
  - `skyforge.priorityClasses.create`
  - `skyforge.priorityClasses.core.*`
  - `skyforge.priorityClasses.integrations.*`
- Assign classes:
  - Core: `skyforge.corePriorityClassName`, `skyforge.server.priorityClassName`, `skyforge.worker.priorityClassName`
  - Heavy integrations: `skyforge.integrationsPriorityClassName`, `skyforge.rapid7.priorityClassName`, `skyforge.elk.priorityClassName`
- Core API disruption budget:
  - `skyforge.server.pdb.enabled`
  - `skyforge.server.pdb.minAvailable`

## Integration auth modes (sidebar)
- Native OIDC (no Skyforge SSO proxy hop): `Gitea`, `NetBox`, `Nautobot`, `Coder`, `API Testing`.
- Native OIDC (no Skyforge SSO proxy hop): `Grafana` (via Dex static client `grafana`).
- `Gitea` onboarding defaults are controlled by `skyforge.gitea.oidc.*`; the prod baseline should keep
  auto-registration enabled and account linking set to `auto` so first-time Dex users land directly in Gitea.
- `Coder` onboarding defaults are controlled by `skyforge.coder.*`; the chart now bootstraps a first owner
  account by default and keeps Dex-backed OIDC auto-login/signups enabled so users land directly in Coder instead
  of the first-user setup flow.
- `Grafana` native OIDC keeps the browser redirect on `https://<hostname>/dex/auth`, but defaults the
  server-side token and userinfo exchange to in-cluster Dex (`http://dex:5556/dex/...`) so Grafana does not fail
  OAuth completion on internal TLS or ingress trust issues.
- OIDC-gated at edge (Skyforge/Dex SSO proxy): `Prometheus`, `Jira`, `Rapid7`, `ELK`, `Infoblox`.
  - Gate controls (enabled by default when integration is enabled):
    - `skyforge.jira.oidc.enabled`
    - `skyforge.rapid7.oidc.enabled`
    - `skyforge.elk.oidc.enabled`
    - `skyforge.infoblox.oidc.enabled`
  - This mode requires:
    - `skyforge.dex.enabled=true`
    - `skyforge.auth.mode=oidc`
  - Managed `Jira` can now preseed its Postgres `dbconfig.xml` from
    `skyforge.jira.database.*` so first-run users land in the app instead of the
    Atlassian database setup wizard.
  - `Rapid7` TLS upstream is controlled by `skyforge.rapid7.oidc.upstream*`.
  - `Infoblox` defaults to HTTP upstream port `80` in OIDC gate mode; override with
    `skyforge.infoblox.oidc.upstream*` if HTTPS upstream is required.
- Direct route (unauthenticated docs endpoint): `ReDoc` (`/redoc` routes directly to `redoc` service).
- If converting a proxy-backed integration to native OIDC, hard-cut the proxy route and keep the portal launch URL on the tool's native OIDC start endpoint.

## Service URLs
- `GITEA_ROOT_URL`: generated from `skyforge.hostname`
- Human-readable artifacts browser: `https://<hostname>/files` (redirects to `/dashboard/s3`)
- Raw object storage route: `https://<hostname>/files/<object-key>`

## Portal build artifacts
- `components/server/frontend/frontend_dist` is the canonical embedded SPA output consumed by the server binary.
- `components/portal` builds directly into that directory:
  - `pnpm build`
  - `scripts/sync-frontend-dist.mjs`
- If portal code changes are part of a rollout, the corresponding `components/server/frontend/frontend_dist/*` updates must be included intentionally in the same rollout.

## Embedded tool launch and wake rules
- Tool visibility is controlled by the tool catalog and the user's UI experience mode (`simple` or `advanced`).
- Standby integrations (`NetBox`, `Nautobot`, `Rapid7`, `Kibana`) expose a `wakeAction` through `/api/platform/integrations/status`.
- Wake semantics are intentionally narrow:
  - users who can already open the advanced embedded tool may wake it to `1` replica
  - broader scale control still requires `manage_integrations`
- If wake is blocked, the embedded tool page must say so explicitly instead of implying auto-start.

## Where to set values
```bash
$EDITOR deploy/skyforge-values.yaml
$EDITOR deploy/skyforge-secrets.yaml
```

Apply:
```bash
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  -f deploy/skyforge-values.yaml \
  -f deploy/skyforge-secrets.yaml
```
