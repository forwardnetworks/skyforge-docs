# Workspaces + sync

Skyforge keeps a shared workspace PVC that backs the VS Code experience. The
workspace sync job pulls workspace/user Git repos into the shared volume so users
can browse and edit them in the browser.

## Paths
- `/workspace/workspaces/<workspace-slug>`: shared workspace repos.
- `/workspace/users/<username>/`: per-user workspace folder.
- `/workspace/users/<username>/s3`: placeholder for S3/MinIO downloads.
- `/workspace/users/<username>/anonymous`: placeholder for anonymous uploads.

## Sync behavior
- Repos are pulled from Gitea every minute.
- Local edits can be overwritten unless they are committed and pushed.
- Use normal Git workflows from the VS Code terminal.

## S3 / MinIO
- Artifacts live in the MinIO bucket (S3-compatible).
- Use the console at `https://<skyforge-host>/minio-console/`.
- Store personal artifacts under `files/users/<username>/`.
- Anonymous uploads use `anonymous/` or `files/` prefixes.
- Artifacts are mirrored into `/workspace/users/<username>/s3` (download-only).
- Do not edit files inside the mirror; upload via S3 instead.
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
