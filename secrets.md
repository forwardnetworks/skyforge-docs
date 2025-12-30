# Secrets

Skyforge deployments rely on Kubernetes Secrets for TLS, local admin bootstrap, and integration credentials.

## Helm chart behavior
- `secrets.create: true`: Helm will create secrets from values under `secrets.items` (safe for local/dev only).
- `secrets.create: false`: Secrets must already exist in the target namespace (recommended for real environments).

Starting with chart `0.2.23`, when `secrets.create: true` the chart preserves existing secret key values if the corresponding Helm value is empty. This prevents accidental secret “blanking” during upgrades.

## Minimum required secrets
At a minimum, the release expects these secrets to exist in the namespace:
- `proxy-tls` (TLS secret used by Traefik IngressRoutes)
- `skyforge-admin-shared` (shared local admin password for bootstrap + provisioning)
- `skyforge-session-secret` (Skyforge session signing secret)

Additional secrets may be required depending on which integrations are enabled (LDAP, EVE, Netlab, etc).

## Full stack (recommended)
For a typical Skyforge deployment (Semaphore, Gitea, NetBox, Nautobot, Hoppscotch), you should also set:
- `postgres-skyforge-password` (Postgres superuser password for the in-cluster DB provision hook)
- `db-*` database user passwords (`db-semaphore-password`, `db-gitea-password`, `db-netbox-password`, `db-nautobot-password`, `db-skyforge-server-password`, `db-hoppscotch-password`)
- `gitea-secret-key` (required by the admin bootstrap job)
- `netbox-secret-key` and `netbox-superuser-api-token`
- `nautobot-secret-key` and `nautobot-superuser-api-token`

## Hoppscotch
If you enable Hoppscotch, create:
- `hoppscotch-secrets` with:
  - `database_url` (Postgres URL for the `hoppscotch` DB/user)
  - `data-encryption-key` (exactly 32 characters; keep it stable or Hoppscotch will refuse to start)

## Example (do not commit real secrets)
See `skyforge-private/deploy/skyforge-secrets.example.yaml`.
