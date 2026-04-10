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
- Skyforge also includes an object-store mirror cron that copies all objects from in-cluster `s3gw` to AWS S3.
- Configure mirror target with:
  - `SKYFORGE_S3GW_AWS_BACKUP_BUCKET` (required)
  - `SKYFORGE_AWS_ACCESS_KEY_ID` + `SKYFORGE_AWS_SECRET_ACCESS_KEY` (required)
  - `SKYFORGE_S3GW_AWS_BACKUP_ENDPOINT` (optional, default `s3.us-west-2.amazonaws.com`)
  - `SKYFORGE_S3GW_AWS_BACKUP_USE_SSL` (optional, default `true`)
  - `SKYFORGE_S3GW_AWS_BACKUP_PREFIX` (optional key prefix)

## Restore sequence
1. Stop writes (scale API/worker down)
2. Restore Postgres
3. Restore object buckets
4. Scale up services
5. Run smoke test (`/status/summary`, run create/start/destroy)
