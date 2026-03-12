# Skyforge Server -> Postgres state

Skyforge Server stores platform state in Postgres (`db`) for durability and easier backup/restore.

## What is stored in Postgres
- users
- user scopes (per username) and membership mappings
- AWS SSO token records
- audit log
- policy/resource inventory

## Target database
- database: `skyforge_server`
- role/user: `skyforge_server`

## Secret source
Set DB credentials in `deploy/skyforge-secrets.yaml`:
- `secrets.items.db-skyforge-server-password.db-skyforge-server-password`

Chart will render/create `db-skyforge-server-password` secret from this value.

## Provision role + database
`db-provision` is chart-owned and runs as a Helm hook on install/upgrade.

To re-run explicitly, run a Helm upgrade (same values you use for deploy):
```bash
helm upgrade --install skyforge components/charts/skyforge \
  -n skyforge \
  -f components/charts/skyforge/values-prod-skyforge-local.yaml \
  -f deploy/examples/values-k3d-dev.yaml \
  -f .tmp/k3d-skyforge/skyforge-secrets.yaml
```

## Runtime env (server)
- `SKYFORGE_DB_HOST=db`
- `SKYFORGE_DB_PORT=5432`
- `SKYFORGE_DB_NAME=skyforge_server`
- `SKYFORGE_DB_USER=skyforge_server`
- `SKYFORGE_DB_PASSWORD` from secret `db-skyforge-server-password`
- `SKYFORGE_DB_SSLMODE=disable`

## Migrations
Run the migration job:
```bash
kubectl -n skyforge delete job/skyforge-migrate --ignore-not-found
kubectl -n skyforge apply -f components/charts/skyforge/files/manifests/skyforge-migrate-pod.yaml
```
