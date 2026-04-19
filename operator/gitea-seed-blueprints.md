# Seeding Template Catalog into Gitea (Operator)

Skyforge loads templates by listing files from a shared template repository in Gitea.
If your Gitea instance is brand new (or the repo was reset), seed the template catalog repo.

This guide assumes:
- You can reach Gitea via the Skyforge bridge `https://<hostname>/api/git/sso?next=/git/` (preferred), or directly at `/git/`
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
git lfs install
git lfs push --all gitea main
```

KNE DNS-1035 normalization is now plugin-native in netlab KNE generation;
the catalog repo does not require a Gitea Action workflow for node-name fixes.

If you seed a repo that contains Git LFS pointers without pushing the LFS
objects, the blueprints repo looks healthy but demo reset replay will fail when
it tries to fetch the seed archives.

For that reason, prefer `scripts/push-blueprints-to-gitea.sh` from an operator
host with `git-lfs` installed. Do not rely on the in-cluster reseed fallback
for LFS-backed assets unless you have replaced its image with one that includes
`git-lfs`.

## 3) Confirm Skyforge can list templates

In Skyforge UI:
- Go to **Create Deployment**
- Ensure templates load for Netlab/KNE/Terraform (depending on what you seeded)

If templates still do not load:
- Confirm user scope references the shared catalog (`skyforge/blueprints`).
- Confirm the repo branch exists (`main`) and the repo is readable by the Skyforge server.
