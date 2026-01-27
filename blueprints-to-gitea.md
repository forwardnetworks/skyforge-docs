# Uploading Blueprints (Templates) to Gitea

Skyforge reads “blueprints” (deployment templates) from a shared Gitea repo (default: `skyforge/blueprints`). If that repo is empty, the UI will show “failed to load templates” for Netlab/Containerlab/Terraform.

This doc describes the **admin workflow** to sync the local `blueprints/` directory into Gitea.

## Preconditions

- You can reach Skyforge over HTTPS at `https://<skyforge-host>/`.
- Gitea is reachable under the same host at `https://<skyforge-host>/git/`.
- You have the Gitea admin username/password (in Skyforge it’s typically the same as the Skyforge admin shared password).

## One-time: make sure the Gitea admin is usable

If you see an API error like:

`"You must change your password. Change it at: https://<skyforge-host>/git/user/change_password"`

then the Gitea user is in a “must change password” state.

Fix options:

1) **Preferred (UI):** login to Gitea as the admin user and change the password once.
2) **Bootstrap Job (cluster):** rerun the Gitea admin bootstrap job (Skyforge chart includes it as a Helm hook). If it didn’t run, you can apply the Job manifest from the chart:
   - Source: `charts/skyforge/files/kompose/gitea-admin-bootstrap-job.yaml`
   - Apply it as a normal Job (remove the Helm hook annotations or rename the Job to avoid conflicts).

After that, the admin should be able to use the REST API without 403 errors.

## Sync blueprints using `pushblueprints`

Skyforge includes a small CLI that syncs the repo content:

- Location: `server/cmd/pushblueprints`
- Source directory: defaults to `../blueprints` relative to `server/`

From this repo:

```bash
cd skyforge-private/server

go run ./cmd/pushblueprints \
  --gitea-api-url "https://<skyforge-host>/git" \
  --gitea-username "skyforge" \
  --gitea-password "<password>" \
  --branch main
```

### TLS note (self-signed / internal PKI)

If your HTTPS certificate isn’t trusted by your machine yet, add:

```bash
  --skip-tls-verify
```

Or set:

```bash
export GITEA_SKIP_TLS_VERIFY=true
```

## Verify

- In Gitea: `Explore` → repositories → `skyforge/blueprints` should contain:
  - `containerlab/`
  - `netlab/`
  - `terraform/`
- In Skyforge: Create Deployment → Template dropdowns should populate.

## Updating templates

Whenever `blueprints/` changes:

1) Commit/push your changes to this repo (optional, but recommended).
2) Re-run the `pushblueprints` command above to re-sync into Gitea.

