# Push Blueprints to Gitea

Skyforge maintains a shared, public blueprint catalog repo (default: `skyforge/blueprints`) so users can browse templates via Gitea **Explore** and select them in the UI.

This repo is created automatically on Skyforge startup, but it starts with only a minimal “smoke” topology. This guide shows how to push the full local `blueprints/` tree into Gitea.

## Prereqs

- You have a Gitea admin user/password (in Skyforge deployments, the `skyforge` user is created automatically).
- The Skyforge repo is checked out locally (contains `blueprints/containerlab`, `blueprints/netlab`, `blueprints/terraform`).

## Run

From `skyforge-private/`:

```bash
# Gitea is protected by Skyforge SSO at /git, so use a port-forward to
# talk to Gitea's API directly.
#
# In another terminal:
#   KUBECONFIG=.kubeconfig-skyforge kubectl -n skyforge port-forward svc/gitea 3000:3000
export GITEA_API_URL="http://127.0.0.1:3000"
export GITEA_USERNAME="skyforge"
export GITEA_PASSWORD="<skyforge admin password>"

cd server
go run ./cmd/pushblueprints \
  --gitea-api-url "$GITEA_API_URL" \
  --gitea-username "$GITEA_USERNAME" \
  --gitea-password "$GITEA_PASSWORD" \
  --owner skyforge \
  --repo blueprints \
  --branch main \
  --src ../blueprints \
  --include containerlab,netlab,terraform
```

## Dry run

```bash
cd server
go run ./cmd/pushblueprints \
  --gitea-api-url "$GITEA_API_URL" \
  --gitea-username "$GITEA_USERNAME" \
  --gitea-password "$GITEA_PASSWORD" \
  --src ../blueprints \
  --dry-run
```

## Notes

- This tool **only upserts** files; it does not delete removed files from the repo.
- By default we sync only `containerlab`, `netlab`, and `terraform` (not `labpp`).
