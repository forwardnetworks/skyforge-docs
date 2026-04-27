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

## Forward platform backups via Skyforge
- The supported backup contract is platform-managed Forward backups to
  in-cluster `s3gw`; those backups remain the source of truth for platform
  restore.
- Forward 26.4 snapshot upload paths also require the in-cluster CBR server,
  local CBR agent, and CBR S3 agent to be present. Treat `fwd-cbr-server`,
  `fwd-cbr-agent`, and `fwd-cbr-s3-agent` as runtime dependencies for Forward
  snapshot processing, not as the primary Skyforge backup strategy.
- The canonical chart values live under `skyforge.backups.forward.*` and should point at the Longhorn-backed platform backup target:
  - `engine: longhorn`
  - bucket `forward-platform-backups`
  - daily schedule / retention
  - protected PVC list for the supported Forward stateful set
- Built-in `fwd-collector` is not part of the supported production backup
  contract.
- `skyforge.backups.forwardRaw.enabled=true` remains available only as an opt-in legacy escape hatch while migrating older node-local storage contracts.
- `skyforge.backups.localSpread.enabled=true` and `skyforge.backups.offsiteRaw.enabled=true` are likewise legacy adjuncts, not part of the default supported production backup signal.
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

- `backup-postgres-s3` is still scheduled and unsuspended
- if legacy raw backup DaemonSets are enabled, they are healthy on all expected nodes
- local backup root: `/var/lib/skyforge/local-backups`
- off-cluster mirror root: `/mnt/hetzner-wireguard/skyforge-backups`

Use:

```bash
./scripts/verify-stateful-backups.sh
./scripts/storage-pvc-inventory.sh
```
