# User Data + Sync

Skyforge stores user data on a shared PVC used by Coder. User repos and lab
artifacts are materialized under a per-user directory so engineers can browse
and edit files in the browser.

## Paths
- `/var/lib/skyforge/users/<username>/`: per-user data folder.
- `/var/lib/skyforge/users/<username>/s3`: placeholder for S3 downloads.
- `/var/lib/skyforge/users/<username>/anonymous`: placeholder for anonymous uploads.

## Sync behavior
- Use normal Git workflows from the Coder terminal.
- Local edits should be committed/pushed so user state stays durable.

## Object storage (S3-compatible)
- Artifacts live in the object storage bucket.
- Store personal artifacts under `files/users/<username>/`.
- Anonymous uploads use `anonymous/` or `files/` prefixes.
- Artifacts are mirrored into `/var/lib/skyforge/users/<username>/s3` (download-only).
- Do not edit files inside the mirror; upload via S3 instead.
- Gitea stores large assets (LFS + attachments + misc storage) in the `gitea` bucket; git repo data remains on the `gitea-data` PVC.

Example (`aws` cli):
```bash
aws --endpoint-url https://<skyforge-host>/files \
  s3 ls s3://skyforge-files/files/users/<username>/
```

Example (anonymous drop):
```bash
curl -T ./file.txt https://<skyforge-host>/files/file.txt
```

## API scope
- Canonical routes are user-scoped (`/api/...`).
- The wildcard compatibility path (`/api/*`) has been removed.
- Variable groups are user-scoped (`/api/variable-groups...`).

## Configuration
- `SKYFORGE_OBJECT_STORAGE_ENDPOINT` and `SKYFORGE_OBJECT_STORAGE_USE_SSL` drive the mirror.
- The mirror uses the configured object storage access key/secret.

## Deployment environment overrides
Users can define reusable variable groups, and each deployment can include per-deployment overrides.

- Variable groups live in user settings and are injected into native runs first.
- Deployment overrides use `KEY=value` pairs and override any group values.
- Netlab users can inspect `netlab show defaults` from the deployments form to see server defaults.
