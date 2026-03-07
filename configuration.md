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
  - Browser login uses `GET /api/oidc/login`
  - Supported OIDC topology is `Skyforge -> Dex -> IdP`
  - For Okta, keep `skyforge.dex.enabled=true`, `skyforge.dex.manageConfig=true`, `skyforge.dex.authMode=oidc`, and populate `skyforge.dex.oidc.*` + `dex-oidc-client-secret`
- Dex connector settings (`skyforge.dex.*`) control Dex's upstream identity provider. They do not replace `skyforge.auth.mode`.

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
