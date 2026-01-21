# SeaweedFS Cutover (Replace MinIO for S3)

This runbook covers **Phase 1**: replacing MinIO with SeaweedFS **S3 gateway** for Skyforge object storage.

It intentionally keeps **Longhorn PV/PVC** unchanged.

## Preconditions

- Cluster running Skyforge via Helm.
- Secrets exist:
  - `object-storage-access-key` / `object-storage-secret-key` (Skyforge uses these already).
- You can reach the cluster (`KUBECONFIG=.kubeconfig-skyforge` or equivalent).

## 1) Enable SeaweedFS S3 (in values)

Set:

- `skyforge.seaweedfs.enabled: true`
- `skyforge.objectStorage.endpoint: seaweedfs:8333`
- `skyforge.objectStorage.useSsl: false`

Apply:

`KUBECONFIG=.kubeconfig-skyforge helm upgrade --install skyforge charts/skyforge -n skyforge -f deploy/skyforge-values.yaml -f deploy/skyforge-secrets.yaml --wait --timeout 10m`

## 2) Verify buckets exist

The chart creates buckets via `seaweedfs-s3-init`:

`KUBECONFIG=.kubeconfig-skyforge kubectl -n skyforge get job seaweedfs-s3-init`

If it failed, inspect logs:

`KUBECONFIG=.kubeconfig-skyforge kubectl -n skyforge logs job/seaweedfs-s3-init`

## 3) Migrate objects from MinIO (optional, if you had data)

If you are cutting over an existing environment with artifacts in MinIO:

1. Keep MinIO running temporarily (do **not** set `skyforge.seaweedfs.enabled` yet).
2. Deploy SeaweedFS with a different endpoint (e.g. `seaweedfs:8333`) and create buckets.
3. Copy objects:
   - Using `aws s3 sync` with two endpoints (recommended).

Example (run from a pod with AWS CLI, or locally if network allows):

```
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

aws --endpoint-url http://minio:9000 s3 sync s3://skyforge-files s3://skyforge-files --endpoint-url http://seaweedfs:8333
aws --endpoint-url http://minio:9000 s3 sync s3://skyforge-artifacts s3://skyforge-artifacts --endpoint-url http://seaweedfs:8333
```

Then cut over `skyforge.objectStorage.endpoint` to `seaweedfs:8333` and disable MinIO resources.

## 4) Validation

- UI `S3` page should list objects.
- Creating a deployment should upload topology artifacts successfully.

## Notes

- “Gitea backed by S3” is not the same as “repo storage in S3”. Repo storage still needs a filesystem
  (either PV, or a filer/CSI presenting a filesystem). We can configure S3 for attachments/LFS later.
