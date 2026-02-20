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

## 2) Push the repo contents from the Skyforge blueprints directory

From a machine that has this repository checked out (for example, the Skyforge host VM):

```bash
cd skyforge-private/blueprints

# Initialize a new repo locally (one time only)
git init
git branch -M main

# Add and commit the blueprints
git add .
git commit -m "Seed Skyforge blueprints"

# Add the Gitea remote and push
git remote add origin https://<gitea-host>/skyforge/blueprints.git
git push -u origin main
```

Notes:
- Use the correct owner in the URL (`skyforge/blueprints.git` above is just an example).
- If you prefer SSH: use the Gitea SSH clone URL instead of HTTPS.

## 3) Confirm Skyforge can list templates

In Skyforge UI:
- Go to **Create Deployment**
- Ensure templates load for Netlab/Containerlab/Terraform (depending on what you seeded)

If templates still do not load:
- Confirm Skyforge My Settings Git defaults (`Gitea API URL`, `Gitea owner`, `Gitea repo`) match the repo you created.
- Confirm the repo branch exists (`main`) and the repo is readable by the Skyforge server.
