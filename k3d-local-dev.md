# Local k3d Dev Cluster (default-safe workflow)

Use this workflow for day-to-day development to avoid accidental prod operations.

## Recreate local cluster

```bash
cd /home/captainpacket/src/skyforge
./scripts/k3d-recreate-skyforge.sh
```

What it does:
- deletes existing `k3d` clusters named `skyforge` (and legacy `skyforge-qa` by default),
- creates `k3d-skyforge` with prod-like k3s/Cilium settings,
- writes kubeconfig to `.kubeconfig-skyforge`,
- sets context to `k3d-skyforge`.

## Deploy Skyforge locally

```bash
cd /home/captainpacket/src/skyforge
./scripts/deploy-skyforge-local.sh
```

Defaults:
- values profile: `deploy/examples/values-k3d-dev.yaml`
- generated secrets: `.tmp/k3d-skyforge/skyforge-secrets.yaml`
- hostname: `skyforge.local.forwardnetworks.com`
- local auth login: `skyforge`
- local auth password: `skyforge`
- host exposure: loopback only (`127.0.0.1:80` / `127.0.0.1:443`)
- local deploy refreshes `dex-config` so local auth changes are reapplied

Add a hosts entry on the local workstation:

```text
127.0.0.1 skyforge.local.forwardnetworks.com
```

Authentication uses the same browser auth contract as other environments:
- `skyforge.auth.mode=password` makes the portal use direct `POST /api/login`
- `skyforge.auth.mode=oidc` makes the portal use `/api/oidc/login`

For local k3d, keep `skyforge.auth.mode=password` unless you are explicitly testing OIDC.

If `~/.docker/config.json` exists, the script also creates `ghcr-pull` in the `skyforge` namespace.

Override the local login only when needed:

```bash
SKYFORGE_ADMIN_USER=myuser SKYFORGE_ADMIN_PASS='mypassword' ./scripts/deploy-skyforge-local.sh
```

Force fresh local secrets generation when you want a full reset:

```bash
SKYFORGE_REGENERATE_SECRETS=true ./scripts/deploy-skyforge-local.sh
```

## Required local context

Operational scripts now default to `.kubeconfig-skyforge` and require context `k3d-skyforge`:
- `scripts/reset-skyforge.sh`
- `scripts/verify-install.sh`
- `scripts/prepull-images-k8s.sh`
- `scripts/push-blueprints-to-gitea.sh`

If context is prod-like or non-local, scripts fail fast.

## Intentional overrides

Only use these for deliberate non-local operations:
- `SKYFORGE_ALLOW_NON_LOCAL_CONTEXT=true`
- `SKYFORGE_ALLOW_PROD_CONTEXT=true`

Production deploy remains blocked by default and now requires:

```bash
SKYFORGE_ALLOW_PROD_DEPLOY=true ./scripts/deploy-skyforge-prod-safe.sh
```
