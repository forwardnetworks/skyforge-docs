# Syncing Blueprints to Gitea (Admin)

Skyforge expects the shared Blueprints catalog to be available in the Gitea repo `skyforge/blueprints` (public).

This repo is the source of truth for those files:
- `skyforge-private/blueprints/` (subdirs like `containerlab/`, `netlab/`, `terraform/`)

## Option A: Run from your workstation (recommended)

1) Clone/update the Skyforge repo locally and `cd` into it:

```bash
cd skyforge-private
```

2) Run the sync tool (it will create the repo if missing, and force it to public):

```bash
cd server
go run ./cmd/pushblueprints \
  --gitea-api-url "https://<skyforge-host>/git/api/v1" \
  --gitea-username "skyforge" \
  --gitea-password "<admin-password>" \
  --owner "skyforge" \
  --repo "blueprints" \
  --branch "main" \
  --include "containerlab,netlab,terraform" \
  --skip-tls-verify
```

Notes:
- `--gitea-api-url` must point to the Gitea API root and can include `/api/v1` or omit it.
- Use `--dry-run` to see what would be pushed without writing.
- Do **not** commit credentials; prefer passing the password via your shell history-safe method or `--gitea-password-file`.
- Only use `--skip-tls-verify` for self-signed/internal deployments.

## Option B: Run on the Skyforge host

This is useful for OSS/self-hosted operators who don’t want to run tooling on their laptop.

1) Install prerequisites on the host:
- `git`
- `go` (toolchain for this repo)

2) Clone the repo and run the same command as Option A.

## Verifying in the UI

1) Open Skyforge and go to `Dashboard → Deployments → Create`.
2) Ensure templates load for `Netlab` / `Containerlab`.
3) For Netlab templates, use **Validate** before **Create**. Validation uses the in-cluster netlab validator job and will fail fast on YAML errors or unsupported constructs.
