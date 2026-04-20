# Backups & Restore (Skyforge)

Skyforge state is split across:
1. Postgres (required)
2. S3-compatible object storage (artifacts)
3. Gitea (optional, depending on usage)

## Goals
- Scheduled backups
- Off-cluster copy
- Simple restore path

## Recommended backup set
### Postgres
- `pg_dump` logical backup (daily)
- optional storage snapshots

### Object storage
- bucket replication/mirroring to backup bucket
- include `skyforge-files` and `gitea` buckets when used

### Gitea (optional)
- backup Gitea DB + storage if treated as source-of-truth

## Kubernetes-native approach
- CronJob: `pg_dump` -> gzip -> upload to S3
- CronJob or native replication: mirror object buckets
- Keep retention policy (for example 14 days)

## Forward backups via Skyforge
- Skyforge admin API can configure Forward CBR to use in-cluster `s3gw` (`StorageType=S3`) and keep scheduled backups enabled.
- When Forward native CBR/S3 backups are disabled in on-prem mode, back up the Forward PVC data directly.
- Enable `skyforge.backups.forwardRaw.enabled=true` to run a DaemonSet that rsyncs Forward PVC host-path data from `/opt/local-path-provisioner` to the mounted offsite destination (for example a Hetzner WireGuard volume mount) from every eligible node.
- The default Forward raw backup set includes:
  - `pvc-fwd-appserver`
  - `pvc-fwd-backend-master`
  - `pvc-fwd-collector`
  - `pvc-fwd-efs`
  - Forward Postgres PVCs
  - Forward aggregated log PVCs
- For migration prep and any remaining node-local workloads, use:
  - `skyforge.backups.localSpread.enabled=true` to spread backup artifacts onto each worker node host disk.
  - `skyforge.backups.offsiteRaw.enabled=true` to run a per-node DaemonSet that continuously rsyncs those local artifacts to a mounted offsite path (for example a Hetzner WireGuard volume mount).
- Optional object-store mirror is still available for S3-compatible offsite targets:
  - `SKYFORGE_OBJECT_MIRROR_BUCKET`
  - `SKYFORGE_OBJECT_MIRROR_ENDPOINT`
  - `SKYFORGE_OBJECT_MIRROR_USE_SSL`
  - `SKYFORGE_OBJECT_MIRROR_PREFIX`
  - `SKYFORGE_OBJECT_MIRROR_ACCESS_KEY_ID` + `SKYFORGE_OBJECT_MIRROR_SECRET_ACCESS_KEY`

## Restore sequence
1. Stop writes (scale API/worker down)
2. Restore Postgres
3. Restore object buckets
4. Scale up services
5. Run smoke test (`/status/summary`, run create/start/destroy)

## Backup verification

Before any storage migration or reboot window, verify:

- `backup-local-spread`, `backup-offsite-raw`, and `backup-forward-raw` are healthy on all expected nodes
- `backup-postgres-s3` is still scheduled and unsuspended
- local backup root: `/var/lib/skyforge/local-backups`
- off-cluster mirror root: `/mnt/hetzner-wireguard/skyforge-backups`

Use:

```bash
./scripts/verify-stateful-backups.sh
./scripts/storage-pvc-inventory.sh
```
