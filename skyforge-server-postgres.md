# Skyforge Server → Postgres state (current)

Skyforge Server stores its state in the shared Postgres service (`db`) so the platform is easier to scale/backup and doesn’t depend on a single pod’s filesystem.

## What is stored in Postgres
State is stored in tables created/managed by Skyforge Server at startup (idempotent DDL):
- Users (`sf_users`)
- Projects + memberships + group mappings (`sf_projects`, `sf_project_members`, `sf_project_groups`)
- AWS SSO token records (`sf_aws_sso_tokens`)
- Per-project AWS static credentials placeholder (`sf_project_aws_static_credentials`)
- Audit log (`sf_audit_log`)
- Governance inventory (`sf_resources`, `sf_resource_events`, `sf_cost_snapshots`, `sf_usage_snapshots`)

Non-goals (still file-based for now):
- Netlab “state root” (`SKYFORGE_NETLAB_STATE_ROOT`)
- `platform-data` (`/var/lib/skyforge/platform-data/*`) produced by `healthwatch` and read by the UI

## Target architecture
- Keep using the **existing** Postgres instance (`db`) that already hosts `semaphore`, `netbox`, `nautobot`, `gitea`.
- Add a dedicated database + role for Skyforge Server:
  - database: `skyforge_server`
  - role/user: `skyforge_server`
- Skyforge Server uses Postgres for all “state” reads/writes when `SKYFORGE_STATE_BACKEND=postgres`.

## DB provisioning (k3s)
The `db-provision` job provisions the `skyforge_server` role + database using inline SQL in the job manifest (no bootstrap scripts).

### Secret
- Local secret file (gitignored): `./secrets/db_skyforge_server_password`
- Kubernetes Secret: `db-skyforge-server-password` created by the kustomize secrets overlay (`k8s/overlays/k3s-traefik-secrets`).

### Provision role + DB
Re-run the provisioning job:
```bash
kubectl -n skyforge delete job/db-provision --ignore-not-found
kubectl -n skyforge apply -f k8s/kompose/db-provision-job.yaml
```

## Skyforge Server runtime config
DB connection env vars:
- `SKYFORGE_DB_HOST=db`
- `SKYFORGE_DB_PORT=5432`
- `SKYFORGE_DB_NAME=skyforge_server`
- `SKYFORGE_DB_USER=skyforge_server`
- `SKYFORGE_DB_PASSWORD` (from the `db-skyforge-server-password` secret)
- `SKYFORGE_DB_SSLMODE=disable` (in-cluster)
- `SKYFORGE_STATE_BACKEND=postgres` (recommended explicit switch)

## Schema (canonical source)
The canonical schema is managed by **Atlas migrations** (golang-migrate format) in `server/skyforge/migrations/`, applied by the `skyforge-migrate` Job (one-shot). The job mounts migrations via a ConfigMap and runs the upstream Atlas image directly.

## Running migrations (canonical)

Native k8s job:
```bash
kubectl -n skyforge delete job/skyforge-migrate --ignore-not-found
kubectl -n skyforge apply -f k8s/kompose/skyforge-migrate-pod.yaml
```


Notes:
- Keep encrypting sensitive fields **in-app** (store ciphertext as `text`).
- Avoid requiring superuser DB privileges: don’t depend on extensions (`citext`, `pgcrypto`) for the initial rollout.

## Operational checklist (k3s, single node)
1. Create/update secrets: `kubectl apply -k k8s/overlays/k3s-traefik-secrets`
2. Re-run DB provisioning if needed: `kubectl -n skyforge apply -f k8s/kompose/db-provision-job.yaml`
3. Ensure Skyforge Server is running with `SKYFORGE_STATE_BACKEND=postgres`
4. If the UI shows “API unavailable”, check Skyforge Server logs first; a common cause is broken Semaphore auth (Skyforge Server calls Semaphore to populate runs/templates). Rotate the Semaphore token in the Semaphore UI, update `./secrets/skyforge_semaphore_token`, then re-apply the secrets overlay and restart the server deployment.

## Follow-ups (later)
- Encrypt persisted token/credential fields at rest (AWS SSO tokens, external-cloud static keys) and store only ciphertext.
- Add templates/artifacts metadata tables (history, retention, ownership) and wire into the UI.
- Expand `sf_audit_log` usage to cover project sharing and admin impersonation end-to-end.
- Optionally move `platform-data` (healthwatch output) into Postgres for multi-node HA.
