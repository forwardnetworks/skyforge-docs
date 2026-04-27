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
```

If the repo contains Git LFS pointers, also push LFS objects:

```bash
git lfs install
git lfs push --all gitea main
```

Skyforge demo seed archives are now stored as regular Git blobs (not LFS), so
demo reset/reseed no longer depends on Gitea LFS object integrity.

The in-cluster fallback helper is not suitable for LFS-backed demo seed assets
unless its container image explicitly includes `git-lfs`. The stock Gitea image
does not, so the supported repair path is `scripts/push-blueprints-to-gitea.sh`
from a host with working `git-lfs`.

## Verification

1. Open Skyforge deployment UI and select template source `Blueprints`.
2. Confirm templates under `netlab/` are listed.
3. Confirm KNE-backed runs no longer fail on DNS-1035 node-name errors
   (normalization happens in the netlab KNE plugin at generation time).
