# Seeding Blueprints into Gitea (Operator)

Skyforge loads templates by listing files from a “blueprints” Git repository (Gitea by default).
If your Gitea instance is brand new (or the repo was reset), you may need to seed the blueprints repo.

This guide assumes:
- You can reach Gitea via the Skyforge entrypoint `https://<hostname>/api/gitea/public` (preferred), or directly at `/git/`
- You have the Skyforge admin user credentials for Gitea (or any user who can create repos)

## 1) Create (or verify) the blueprints repo in Gitea

In the Gitea UI:
- Create a repo named `blueprints` under the desired owner/org (commonly the `skyforge` user/org).
- Make it **public** if you want unauthenticated BYOS servers to fetch templates by URL.
- Ensure the default branch is `main`.

## 2) Push the repo contents from this repo's blueprints source

Canonical method (from the repo root):

```bash
export SKYFORGE_HOST="<gitea-host>"
./scripts/push-blueprints-to-gitea.sh
```

Notes:
- The script uses `components/blueprints` as source-of-truth by default.
- Override owner/repo/branch with `BLUEPRINTS_OWNER`, `BLUEPRINTS_REPO`,
  and `BLUEPRINTS_TARGET_BRANCH`.
- For external catalog sources, use `BLUEPRINTS_SRC_MODE=git`.

## 3) Confirm Skyforge can list templates

In Skyforge UI:
- Go to **Create Deployment**
- Ensure templates load for Netlab/Containerlab/Terraform (depending on what you seeded)

If templates still do not load:
- Confirm Skyforge My Settings Git defaults (`Gitea API URL`, `Gitea owner`, `Gitea repo`) match the repo you created.
- Confirm the repo branch exists (`main`) and the repo is readable by the Skyforge server.
