# Reseed the shared template repo in Gitea

Skyforge consumes templates directly from a shared Gitea repo:

- `skyforge/blueprints`

No per-user blueprint copy/sync is required.
CI reseed/sync is disabled; update templates by pushing Git commits to the
catalog repo.

## Canonical reseed flow

```bash
git clone https://github.com/ipspace/netlab-examples.git
cd netlab-examples
git remote add gitea https://<hostname>/git/skyforge/blueprints.git
git push -u gitea main
git lfs install
git lfs push --all gitea main
```

If the repo contains Git LFS pointers and you skip the `git lfs push`, Skyforge
can still see the catalog and branch while demo-seed ZIP downloads fail later
with `gitea lfs batch returned error (404): Not Found`.

## Verification

1. Open Skyforge deployment UI and select template source `Blueprints`.
2. Confirm templates under `netlab/` are listed.
3. Confirm KNE-backed runs no longer fail on DNS-1035 node-name errors
   (normalization happens in the netlab KNE plugin at generation time).
