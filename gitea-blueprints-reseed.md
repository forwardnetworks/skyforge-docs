# Reseed the shared template repo in Gitea

Skyforge consumes templates directly from a shared Gitea repo:

- `skyforge/netlab-examples`

No per-user blueprint copy/sync is required.
CI reseed/sync is disabled; update templates by pushing Git commits to the
catalog repo.

## Canonical reseed flow

```bash
git clone https://github.com/ipspace/netlab-examples.git
cd netlab-examples
git remote add gitea https://<hostname>/git/skyforge/netlab-examples.git
git push -u gitea main
```

## Required automation in the repo

Ensure these files are present in `skyforge/netlab-examples`:

- `.gitea/workflows/dns-normalize.yml`
- `tools/normalize_dns_safe.py`

The workflow auto-normalizes DNS-1035-invalid node names on push.

## Verification

1. Open Skyforge deployment UI and select template source `Blueprints`.
2. Confirm templates under `netlab/` are listed.
3. Confirm run preflight no longer fails with DNS-1035 template node-name errors.
