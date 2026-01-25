# Install (single-node) – k3s + Longhorn + Skyforge

This is the “curl a script” style path intended to be easy to repeat on fresh clusters.

## Prereqs
- A single Linux host (preferably a fresh VM).
- `sudo` access.
- `open-iscsi` available (Longhorn requirement).
- A secrets values file (kept out of git).

## Recommended: run on the host (no tunnels)
Run the installer **on the node** that will host k3s. This avoids SSH tunnel / kubeconfig issues during install drills.

From a checkout of `skyforge-private/` on the node:

```bash
export SKYFORGE_ENV=qa
SKYFORGE_SECRETS_VALUES=./deploy/skyforge-secrets.yaml \
SKYFORGE_GHCR_USERNAME='<github-user-or-bot>' \
SKYFORGE_GHCR_TOKEN='<token-with-read:packages>' \
sudo -E ./scripts/install-on-host.sh
```

Notes:
- If your images are public, omit the `SKYFORGE_GHCR_*` vars.
- If you’re iterating and need a clean slate, add `SKYFORGE_RESET=true` (danger: deletes the namespace + clabernetes CRDs).
- The script uses `deploy/longhorn-values-qa.yaml` defaults (replicas=1). For multi-node prod, override accordingly.
- Do **not** paste tokens into your shell history. Prefer: `read -s SKYFORGE_GHCR_TOKEN; export SKYFORGE_GHCR_TOKEN`

## Post-install
Follow `docs/post-install-verify.md`.
