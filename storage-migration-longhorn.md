# Longhorn Migration Runbook

This is the repo-side cutover plan for moving Skyforge and Forward stateful PVCs
from `local-path` to Longhorn without data loss.

## Rules

- No cutover without verified backups.
- Forward is the highest-priority restore target.
- Longhorn replication is not a backup.
- Critical PVCs must set `storageClassName` explicitly.

## Pre-cutover

1. Install Longhorn on all worker nodes.
2. Verify Longhorn health and replica scheduling.
3. Verify backup coverage:
   - `./scripts/verify-stateful-backups.sh`
   - `./scripts/storage-pvc-inventory.sh`
4. Capture application-consistent exports for:
   - Skyforge Postgres
   - Forward app DB
   - Forward FDB clusters
5. Capture file/object snapshots for:
   - `gitea-data`
   - `s3gw` buckets
   - local/off-cluster backup roots

## Migration order

1. Skyforge core data:
   - `db-data`
   - `redis-data`
   - `gitea-data`
   - `s3gw-data`
   - `platform-data`
   - `skyforge-server-data`
   - `skyforge-prometheus-data`
2. Forward critical data:
   - all `pgdata-fwd-pg-*`
   - `pvc-fwd-appserver`
   - `pvc-fwd-backend-master`
   - `pvc-fwd-collector`
   - `pvc-fwd-efs`
   - `aggregated-logs-*`
3. Remaining managed app PVCs.

## Validation

After cutover:

- all critical PVCs bind to `storageClassName=longhorn`
- `platform-data` and `skyforge-server-data` use the intended shared access mode
- Skyforge API, Git, Launch Lab, and Forward bridge work
- Forward appserver, backend-master, compute/search workers, and PG clusters are healthy
- a worker reboot no longer requires node-local PV recovery for critical workloads

## Rollback

Rollback is backup-driven, not storage-driver-driven:

1. stop writes
2. restore DB exports
3. restore file/object snapshots
4. restore any raw PVC backup artifacts needed for Forward
5. re-run post-restore smoke tests
