# Seeding Template Catalog into Gitea (Operator)

Skyforge loads templates by listing files from a shared template repository in Gitea.
If your Gitea instance is brand new (or the repo was reset), seed the template catalog repo.

This guide assumes:
- You can reach Gitea via the Skyforge entrypoint `https://<hostname>/api/gitea/public` (preferred), or directly at `/git/`
- You have the Skyforge admin user credentials for Gitea (or any user who can create repos)

## 1) Create (or verify) the template repo in Gitea

In the Gitea UI:
- Create a repo named `blueprints` under the desired owner/org (commonly `skyforge`).
- Make it **public** if you want unauthenticated BYOS servers to fetch templates by URL.
- Ensure the default branch is `main`.

## 2) Seed from upstream `ipspace/netlab-examples`

```bash
git clone https://github.com/ipspace/netlab-examples.git
cd netlab-examples
git remote add gitea https://<hostname>/git/skyforge/blueprints.git
git push -u gitea main
```

The repo should include:

- `tools/normalize_dns_safe.py`
- `.gitea/workflows/dns-normalize.yml`

That workflow auto-normalizes DNS-safe names on push.

## 3) Confirm Skyforge can list templates

In Skyforge UI:
- Go to **Create Deployment**
- Ensure templates load for Netlab/Containerlab/Terraform (depending on what you seeded)

If templates still do not load:
- Confirm user scope references the shared catalog (`skyforge/blueprints`).
- Confirm the repo branch exists (`main`) and the repo is readable by the Skyforge server.
