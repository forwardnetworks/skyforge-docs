# Workspaces + sync

Skyforge stores workspace data on a shared PVC used by Coder. User workspaces and
lab repos are materialized under a per-user directory so engineers can browse and
edit files in the browser.

## Paths
- `/var/lib/skyforge/users/<username>/`: per-user workspace folder.
- `/var/lib/skyforge/users/<username>/s3`: placeholder for S3/MinIO downloads.
- `/var/lib/skyforge/users/<username>/anonymous`: placeholder for anonymous uploads.

## Sync behavior
- Use normal Git workflows from the Coder terminal.
- Local edits should be committed/pushed so workspace state stays durable.

## S3 / MinIO
- Artifacts live in the MinIO bucket (S3-compatible).
- Use the console at `https://<skyforge-host>/minio-console/`.
- Store personal artifacts under `files/users/<username>/`.
- Anonymous uploads use `anonymous/` or `files/` prefixes.
- Artifacts are mirrored into `/var/lib/skyforge/users/<username>/s3` (download-only).
- Do not edit files inside the mirror; upload via S3 instead.
- When SeaweedFS is enabled, it replaces MinIO as the backing S3 endpoint (buckets remain the same names).
- Gitea stores large assets (LFS + attachments + misc storage) in the `gitea` bucket; git repo data remains on the `gitea-data` PVC.
Example (mc):
```bash
mc alias set skyforge https://<skyforge-host> <ACCESS_KEY> <SECRET_KEY>
mc ls skyforge/skyforge-files/files/users/<username>/
mc cp skyforge/skyforge-files/files/users/<username>/file.txt ./s3/
```
Example (anonymous drop):
```bash
curl -T ./file.txt https://<skyforge-host>/files/file.txt
```

## Configuration
- `SKYFORGE_OBJECT_STORAGE_ENDPOINT` and `SKYFORGE_OBJECT_STORAGE_USE_SSL` drive the mirror.
- `SKYFORGE_WORKSPACE_S3_BUCKET` overrides the bucket name (default `skyforge-files`).
- The mirror uses the artifacts access key/secret, falling back to the MinIO root user/password if needed.

## Deployment environment overrides
Workspaces can define reusable variable groups, and each deployment can include per-deployment overrides.

- Variable groups live in workspace settings and are injected into native runs first.
- Deployment overrides use `KEY=value` pairs and override any group values.
- Netlab users can inspect `netlab show defaults` from the deployments form to see server defaults.
