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

## Restore sequence
1. Stop writes (scale API/worker down)
2. Restore Postgres
3. Restore object buckets
4. Scale up services
5. Run smoke test (`/status/summary`, run create/start/destroy)
