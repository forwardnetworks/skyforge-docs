# Backups and disaster recovery

Skyforge runs as a Kubernetes workload, but the cluster node still has **stateful data**:

- Postgres databases (`db` PVC): Gitea, NetBox, Nautobot, Hoppscotch, Skyforge state
- Object storage (`minio` PVC): artifacts + Terraform state + file drop
- Workspace PVCs: per-user Coder data

This doc outlines a pragmatic “MVP backup” strategy so you can rebuild the node and recover quickly.

## 1) Back up Postgres locally (MinIO)

Kubernetes CronJob: `k8s/kompose/backup-postgres-minio-cronjob.yaml`.

Note: backup/replication CronJobs are **not deployed by default** in the OSS
overlay. Apply them explicitly (or create your own overlay) if you want
automated backups.

- Runs `pg_dumpall` nightly and writes the compressed dump to the MinIO bucket `skyforge-backups/postgres/`.
- This keeps backups **inside the cluster**, close to the rest of the platform state.
- Default retention: 30 days.

## 2) Replicate MinIO offsite (AWS S3)

Kubernetes CronJob: `k8s/kompose/replicate-minio-aws-s3-cronjob.yaml`.

- Mirrors important MinIO buckets to an AWS S3 bucket.
- Disabled by default (`suspend: true`) until you:
  - create an AWS credentials secret `aws-backup-credentials` (keys: `access_key_id`, `secret_access_key`)
  - set `BACKUP_S3_BUCKET` in the CronJob

This provides the “local first, offsite second” backup model:

1) Postgres dumps land in MinIO
2) MinIO buckets (including the backup bucket) are replicated to AWS S3

## 3) (Optional) Direct Postgres → S3 backup

Legacy CronJob: `k8s/kompose/backup-postgres-s3-cronjob.yaml`.

- Uploads `pg_dumpall` output directly to AWS S3.
- Kept for reference, but the preferred model is MinIO-local + offsite replication.
## 4) Back up MinIO to S3

For MVP, treat MinIO as the “authoritative” store for artifacts/state and replicate to AWS S3:

- Configure MinIO replication to a remote S3 bucket (preferred), or
- Run a scheduled `mc mirror` job to copy buckets to AWS S3.

## 5) Back up Kubernetes manifests/config

- All manifests live in this repo under `k8s/`.
- Keep secrets out of Git; store them in:
  - a password manager, or
  - a private S3 bucket as encrypted tarballs (recommended), or
  - Kubernetes Secret export encrypted with age/sops.

## 6) PV snapshots (optional, recommended with Longhorn)

If you’re using Longhorn:

- Enable recurring snapshots + backups to S3 for the PVs backing:
  - `db-data`, `minio-data`, `gitea-data`
  - `platform-data`, `coder-data`

This gives a fast “restore the volume” path without needing to replay logical dumps.

## Recovery runbook (high level)

1. Recreate the node and install k3s.
2. Restore PVCs (Longhorn restore) **or** deploy and restore Postgres + MinIO from S3.
3. Apply Skyforge manifests: `kubectl apply -k k8s/overlays/k3s-traefik`.
4. Validate `/healthz` and the status page.

## Restore notes (capability)

To do a “100% restore”, you need:

- **Git repo** (GitHub + Gitea)
- **Postgres** data (from MinIO backups or Longhorn snapshot)
- **MinIO** data (replicated to AWS S3 and/or restored from Longhorn snapshot)
- **Kubernetes secrets** (stored out-of-band; without these you can still restore data, but services won’t authenticate correctly)
