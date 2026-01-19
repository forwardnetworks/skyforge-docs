# Backups & Restore (Skyforge)

Skyforge state lives in three places:

1) **Postgres (required)** — system of record
   - Workspaces, deployments, runs/tasks/logs/events, settings, tokens, etc.
2) **Object storage (recommended)** — artifacts
   - Topology graphs, uploaded artifacts, generated bundles, exports, etc.
3) **Gitea (optional, depending on how you use it)** — template/workspace repos
   - Can be treated as source-of-truth or as a cache that is rebuildable.

This runbook describes a Kubernetes-native backup strategy that works well with Skyforge’s “Encore-native” architecture.

## Goals

- Backup on a schedule (daily + optional hourly).
- Store backups in S3/MinIO.
- Simple restore procedure.
- No secrets committed to git.

## What to back up

### Required: Postgres

Backup:
- **Logical dump**: `pg_dump` (portable; easiest for small/medium DBs)
- **Physical backup**: (optional) your storage snapshot solution

Restore:
- `psql < dump.sql` into a fresh DB, or restore a snapshot.

### Recommended: Object storage (MinIO/S3)

Backup:
- Bucket replication to another bucket/cluster, or periodic mirroring (`mc mirror`)

Restore:
- Mirror back into the MinIO bucket(s) Skyforge uses.

### Optional: Gitea

If you treat Gitea as source-of-truth:
- Back up the Gitea Postgres + storage (repos) the same way.

If you treat Gitea as rebuildable/cache:
- You can restore Skyforge + re-provision/sync repos.

## Recommended minimal implementation

### A) Postgres backup Job (pg_dump → S3/MinIO)

Create a Kubernetes CronJob that:
- runs `pg_dump` against the Skyforge Postgres service
- compresses output (`gzip`)
- uploads to MinIO/S3

Key requirements:
- A Secret containing:
  - `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`
  - MinIO/S3 endpoint + bucket + credentials
- Network access from the Job to Postgres and MinIO.

Notes:
- Keep retention (e.g. 14 daily backups) by deleting old objects via `mc rm --older-than`.
- Use UTC timestamps in object keys.

### B) MinIO bucket backup (mirror/replicate)

Option 1: replication
- Configure MinIO bucket replication to another bucket or MinIO instance.

Option 2: CronJob mirror
- `mc mirror --overwrite --remove` from source bucket to backup bucket.

## Restore procedure (high level)

1) **Stop writes**
   - Scale Skyforge API + worker to 0 replicas (or take the cluster out of rotation).
2) **Restore Postgres**
   - Create/restore DB
   - Import the dump (`psql`) or restore snapshot
3) **Restore object storage**
   - Ensure the expected buckets exist
   - Mirror/replicate objects back
4) **Restart Skyforge**
   - Scale back up
   - Verify health (`/status/summary`)
5) **Verify tasks/workflows**
   - Run a small deployment create/start/destroy

## Verification checklist

- `/status/summary` shows `postgres: up`
- `task-workers: up` (recent heartbeat)
- Dashboard loads and lists workspaces/deployments
- A small deployment run produces logs and finishes successfully

## Operational notes

- Skyforge relies on **Encore cron** for internal reconciliation, but backups should be done with Kubernetes-native Jobs for portability.
- If you add a second backup target (off-cluster), treat it as the source for disaster recovery.

