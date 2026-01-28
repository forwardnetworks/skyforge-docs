# Skyforge host-first install (repeatable drills)

This guide is optimized for **repeatable** installs and “clean install drills” by running everything **on the Kubernetes node itself** (no SSH tunnels, no remote kubeconfigs).

## Quickstart

1) SSH to your server and clone the repo

```bash
sudo mkdir -p /opt
sudo chown "$(id -u):$(id -g)" /opt
cd /opt
git clone https://github.com/forwardnetworks/skyforge.git skyforge
cd /opt/skyforge/skyforge-private
```

2) Create a secrets file

- Start from `deploy/skyforge-secrets.example.yaml`
- Save your real values to `deploy/skyforge-secrets.yaml` (do not commit it).

For install drills / quickstarts, you can generate a dev-friendly file:

```bash
./scripts/gen-secrets.sh \
  --hostname "skyforge-qa.local.forwardnetworks.com" \
  --out ./deploy/skyforge-secrets.yaml
```

3) If GHCR images are private, export GHCR credentials (avoid shell history)

```bash
export SKYFORGE_GHCR_USERNAME="<github-user-or-bot>"
read -s SKYFORGE_GHCR_TOKEN
export SKYFORGE_GHCR_TOKEN
```

4) Run the installer (QA by default)

```bash
export SKYFORGE_ENV=qa
export SKYFORGE_SECRETS_VALUES=./deploy/skyforge-secrets.yaml
sudo -E ./scripts/install-on-host.sh
```

5) Upload templates (blueprints) to Gitea

If the UI shows “failed to load templates”, sync the bundled `blueprints/` catalog:

```bash
export SKYFORGE_HOST="skyforge-qa.local.forwardnetworks.com"
export GITEA_SKIP_TLS_VERIFY=true
./scripts/push-blueprints-to-gitea.sh
```

## What the installer does

`scripts/install-on-host.sh`:
- Ensures `open-iscsi` (for Longhorn) when possible.
- Installs k3s (unless `SKYFORGE_K3S_INSTALL=false`).
- Installs Helm (unless `SKYFORGE_HELM_INSTALL=false`).
- Sets `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`.
- Runs `scripts/install-single-node.sh` to install/upgrade Longhorn + Skyforge Helm chart.
- Runs `scripts/verify-install.sh` for a quick sanity check.

## Make it “fail-proof” for drills

### Always pin what you’re testing

For reproducibility, pin the git ref:

```bash
export SKYFORGE_GIT_REF="<tag-or-commit>"
sudo -E ./scripts/install-on-host.sh
```

### Always reset before a drill

If you’re doing repeated install drills, wipe Skyforge state first:

```bash
export SKYFORGE_RESET=true
sudo -E ./scripts/install-on-host.sh
```

`SKYFORGE_RESET=true` is intentionally destructive: it deletes the Skyforge namespace and clabernetes CRDs to avoid Helm/CRD schema conflicts.

If you want to run the reset explicitly (without reinstalling):

```bash
sudo -E ./scripts/reset-skyforge.sh
```

### Don’t target the wrong cluster

`scripts/install-single-node.sh` refuses to run with a non-default `KUBECONFIG` unless you explicitly opt in:

```bash
export SKYFORGE_ALLOW_REMOTE_KUBECONFIG=true
```

Avoid setting this unless you are intentionally targeting a remote cluster.

## Verification

On the node:

```bash
sudo -E ./scripts/verify-install.sh
```

If you know the hostname:

```bash
export SKYFORGE_HOSTNAME="skyforge-qa.local.forwardnetworks.com"
sudo -E ./scripts/verify-install.sh
```

## Common failures and recovery

### ImagePullBackOff

- Verify `ghcr-pull` exists in the `skyforge` namespace.
- Verify your PAT has `read:packages` and is SSO-authorized if required.
- Re-run with exported `SKYFORGE_GHCR_USERNAME`/`SKYFORGE_GHCR_TOKEN` to recreate the pull secret.

### Helm install conflicts / stuck releases

- Re-run with `SKYFORGE_RESET=true`.
- If you are iterating on clabernetes versions, `SKYFORGE_RESET=true` is the fastest way to clear conflicting CRDs.

## Notes for OSS readiness

- Keep LabPP out of the default install path (it depends on private assets).
- Prefer to keep “core” images either public or documented with a GHCR pull secret flow.
