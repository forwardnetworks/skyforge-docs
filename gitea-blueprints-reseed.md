# Reseed the public `skyforge/blueprints` repo (Gitea)

Skyforge expects the public blueprints repo (`skyforge/blueprints`) to contain
top-level template folders like:

- `netlab/…`
- `eve-ng/…` (optional if you do not use EVE-NG)
- `containerlab/…`
- `terraform/…`

If template pickers show “No templates” and the Skyforge server is healthy, the
Gitea blueprints repo is usually missing content or out-of-sync.

`components/blueprints` in this repo is the source-of-truth.

## Canonical reseed command

From the repo root:

```bash
export SKYFORGE_HOST="skyforge.local.forwardnetworks.com"
export GITEA_SKIP_TLS_VERIFY=true
./scripts/push-blueprints-to-gitea.sh
```

Defaults:

- Source mode: `BLUEPRINTS_SRC_MODE=local`
- Source directory: `components/blueprints`
- Target repo: `skyforge/blueprints`
- Target branch: `main`

## Optional: reseed from an external git source

```bash
export SKYFORGE_HOST="skyforge.local.forwardnetworks.com"
export BLUEPRINTS_SRC_MODE=git
export BLUEPRINTS_GIT_URL="https://github.com/forwardnetworks/skyforge-blueprints.git"
export BLUEPRINTS_GIT_REF="main"
./scripts/push-blueprints-to-gitea.sh
```

## Optional overrides

- `BLUEPRINTS_OWNER` (default: `skyforge`)
- `BLUEPRINTS_REPO` (default: `blueprints`)
- `BLUEPRINTS_TARGET_BRANCH` (default: `main`)
- `GITEA_USERNAME` / `GITEA_PASSWORD`
- `KUBECONFIG` (used only when reading password from k8s secret)

## Notes

- Reseed is a force-push by design: the published catalog should exactly match
  the chosen source snapshot.
- Keep top-level layout as `netlab/...`, `containerlab/...`, `terraform/...`
  (not `blueprints/netlab/...`) for `source=blueprints` API paths.
