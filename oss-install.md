# Install (single-node) – k3s + Longhorn + Skyforge

This is the “curl a script” style path intended to be easy to repeat on fresh clusters.

## Prereqs
- A single Linux host with `kubectl` + `helm` installed.
- `open-iscsi` available (Longhorn requirement).
- A secrets values file (kept out of git).

## Script
From a checkout of `skyforge-private/`:

```bash
SKYFORGE_SECRETS_VALUES=./deploy/skyforge-secrets.yaml \
SKYFORGE_GHCR_USERNAME='<github-user-or-bot>' \
SKYFORGE_GHCR_TOKEN='<token-with-read:packages>' \
./scripts/install-single-node.sh
```

Notes:
- If your images are public, omit the `SKYFORGE_GHCR_*` vars.
- The script uses `deploy/longhorn-values-qa.yaml` defaults (replicas=1). For multi-node prod, override accordingly.

## Post-install
Follow `docs/post-install-verify.md`.

