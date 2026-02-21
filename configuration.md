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
- In-cluster Dex (default): `skyforge.dex.enabled=true`, `skyforge.dex.manageConfig=true`, `skyforge.dex.authMode=local`
- Local Dex user password source: `skyforge-admin-shared.password`
- Google OAuth: `skyforge.dex.authMode=google` with `skyforge.dex.google.clientID` + `dex-google-client-secret`
- Generic OIDC (for Okta): `skyforge.dex.authMode=oidc` with `skyforge.dex.oidc.*` + `dex-oidc-client-secret`
- External OIDC: `skyforge.dex.enabled=false` and provide OIDC config/secrets

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
