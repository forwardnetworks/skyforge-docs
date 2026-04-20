# Kubernetes storage (Skyforge on k3s)

Skyforge's intended multi-node storage posture is:

- `longhorn` for critical PVC-backed stateful services
- `local-path` only for disposable or explicitly node-local claims
- local plus off-cluster backups for every dataset that matters

## Intended default: Longhorn

Use Longhorn for:

- `db-data`
- `redis-data`
- `gitea-data`
- `s3gw-data`
- `platform-data`
- `skyforge-server-data`
- `skyforge-prometheus-data`
- Forward Postgres PVCs and core Forward PVC-backed services

Why:

- critical pods must survive worker reboots without node-local PV ownership hacks
- critical PVCs need deterministic `storageClassName`, not inheritance from the cluster default
- `platform-data` and `skyforge-server-data` are shared by multiple pods and should be treated as shared storage contracts

## Local-path is still allowed, but not for critical state

Keep `local-path` only for:

- disposable lab/test PVCs
- temporary scratch data
- workloads where node-local semantics are intentional and recoverable

Do not rely on `local-path` for:

- Gitea repo data
- Skyforge/Postgres state
- Forward Postgres and core Forward PVCs

## Backup contract

Storage replication is not a backup.

Before and after Longhorn migration, keep all of these enabled:

- `skyforge.backups.localSpread`
- `skyforge.backups.offsiteRaw`
- `skyforge.backups.forwardRaw`
- `skyforge.backups.postgres`

The expected backup roots are:

- local: `/var/lib/skyforge/local-backups`
- off-cluster mirror: `/mnt/hetzner-wireguard/skyforge-backups`

Use `scripts/verify-stateful-backups.sh` and `scripts/storage-pvc-inventory.sh`
before any cutover window.
