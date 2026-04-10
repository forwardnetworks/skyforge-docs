# Install (single-node) – k3s + local-path + Skyforge

This is the “curl a script” style path intended to be easy to repeat on fresh clusters.

## Prereqs
- A single Linux host (preferably a fresh VM).
- `sudo` access.
- A secrets values file (kept out of git).

## Recommended: run on the host (no tunnels)
Run the installer **on the node** that will host k3s. This avoids SSH tunnel / kubeconfig issues during install drills.

From a checkout of `skyforge/` on the node:

```bash
./scripts/gen-secrets.sh --hostname "<skyforge-hostname>" --out ./deploy/skyforge-secrets.yaml

export SKYFORGE_ENV=qa
SKYFORGE_SECRETS_VALUES=./deploy/skyforge-secrets.yaml \
SKYFORGE_GHCR_USERNAME='<github-user-or-bot>' \
SKYFORGE_GHCR_TOKEN='<token-with-read:packages>' \
sudo -E ./scripts/install-on-host.sh
```

Notes:
- If your images are public, omit the `SKYFORGE_GHCR_*` vars.
- If you’re iterating and need a clean slate, add `SKYFORGE_RESET=true` (danger: deletes the namespace + kne CRDs).
- The install path is local-path-first (no Longhorn dependency).
- Do **not** paste tokens into your shell history. Prefer: `read -s SKYFORGE_GHCR_TOKEN; export SKYFORGE_GHCR_TOKEN`

## Post-install
Follow `docs/post-install-verify.md`.
