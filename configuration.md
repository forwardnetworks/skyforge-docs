# Configuration quick reference

Skyforge uses typed Encore config (`ENCORE_CFG_SKYFORGE`, `ENCORE_CFG_WORKER`) plus runtime secrets.
For k3s deployments, configure:
- values: `deploy/skyforge-values.yaml`
- secrets: `deploy/skyforge-secrets.yaml` (local-only)

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
- On every Helm install/upgrade, hook job `skyforge-auth-runtime-sync` writes `sf_settings` auth keys (`ui_auth_primary_provider`, `ui_oidc_enabled`, `oidc_*`) from chart values/secrets so runtime auth mode stays aligned with declarative config.
- Dex connector settings (`skyforge.dex.*`) control Dex's upstream identity provider. They do not replace `skyforge.auth.mode`.

## Integration auth modes (sidebar)
- Native OIDC (no Skyforge SSO proxy hop): `Gitea`, `NetBox`, `Nautobot`, `Coder`.
- Native OIDC (no Skyforge SSO proxy hop): `Grafana` (via Dex static client `grafana`).
- OIDC-gated at edge (Skyforge/Dex SSO proxy): `Prometheus`, `Jira`, `Rapid7`, `ELK`, `Infoblox`.
  - Gate controls (enabled by default when integration is enabled):
    - `skyforge.jira.oidc.enabled`
    - `skyforge.rapid7.oidc.enabled`
    - `skyforge.elk.oidc.enabled`
    - `skyforge.infoblox.oidc.enabled`
  - This mode requires:
    - `skyforge.dex.enabled=true`
    - `skyforge.auth.mode=oidc`
  - `Rapid7` TLS upstream is controlled by `skyforge.rapid7.oidc.upstream*`.
  - `Infoblox` defaults to HTTP upstream port `80` in OIDC gate mode; override with
    `skyforge.infoblox.oidc.upstream*` if HTTPS upstream is required.
- Direct route (unauthenticated docs endpoint): `ReDoc` (`/redoc` routes directly to `redoc` service).
- If converting a proxy-backed integration to native OIDC, hard-cut the proxy route and keep the portal launch URL on the tool's native OIDC start endpoint.

## Service URLs
- `GITEA_ROOT_URL`: generated from `skyforge.hostname`
- Object storage route: `https://<hostname>/files/`

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
