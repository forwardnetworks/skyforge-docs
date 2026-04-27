# Helm

Skyforge ships a full Helm chart under `components/charts/skyforge`. The chart renders the
same manifests as the kustomize flow, with value-based substitution for
hostnames, images, and defaults.

## Quickstart

```bash
helm upgrade --install skyforge ./components/charts/skyforge \
  -n skyforge --create-namespace \
  -f values.yaml
```

## OSS baseline (recommended)

Use pre-created Kubernetes secrets and keep Helm in reference-only mode:

```bash
helm upgrade --install skyforge ./components/charts/skyforge \
  -n skyforge --create-namespace \
  --set secrets.create=false \
  -f values.yaml
```

This keeps runtime secrets out of Helm release values/history.

For production/stable environments, keep this invariant on every upgrade:

- `secrets.create=false`
- `secrets.validatePrecreated=true`
- `--reset-values` with your tracked values files
- `--atomic --timeout <bounded>` for rollback on failed revisions

Avoid `--reuse-values` for production upgrades. Reusing historical values can
silently restore older embedded TLS data (`proxy-tls`) and revert certificates.

Run preflight + post-upgrade gates on every release:

```bash
./scripts/preflight-upgrade.sh
helm upgrade --install skyforge ./components/charts/skyforge \
  -n skyforge --create-namespace \
  --atomic --timeout 20m \
  -f <values.yaml> -f <env-values.yaml> -f <secrets.yaml>
./scripts/post-upgrade-gates.sh
```

`check-helm-release-state.sh` is now the supported release-health probe used by
both gate scripts:

- preflight allows a missing release, but fails closed on `pending-*` and
  `failed` release states before a new upgrade starts
- post-upgrade requires the release to resolve to `deployed`
- the helper also prints recent Helm history and the last known deployed
  revision, so operators can see drift/recovery context without manually
  running `helm status` and `helm history`

Standalone usage:

```bash
./scripts/check-helm-release-state.sh
SKYFORGE_EXPECT_STATUS=deployed ./scripts/check-helm-release-state.sh
SKYFORGE_ALLOW_MISSING_RELEASE=true ./scripts/check-helm-release-state.sh
```

For safer operator recovery, the production deploy helper now supports a
two-phase rollout:

```bash
# Phase 1: record the Helm revision and roll the core API/worker images.
SKYFORGE_DEPLOY_PHASE=upgrade-only \
  SKYFORGE_SERVER_IMAGE=<server-image> \
  SKYFORGE_SERVER_WORKER_IMAGE=<worker-image> \
  ./scripts/deploy-skyforge-prod-safe.sh

# Phase 2: run slower reconcile and platform-specific post-Helm steps only
# after the new revision is healthy.
SKYFORGE_DEPLOY_PHASE=reconcile-only \
  ./scripts/deploy-skyforge-prod-safe.sh
```

Use `SKYFORGE_DEPLOY_PHASE=full` (the default) for the existing one-shot flow.
The split phases are useful when Helm revisions are healthy but post-upgrade
reconcile work is slow, risky, or still being debugged.

`preflight-upgrade.sh` now enforces an image contract for Netlab runtime drift:

- `components/server/skyforge/config.cue` and `components/server/worker/config.cue` must agree on `Netlab.Image`.
- merged Helm values (`-f values -f env -f secrets`) must set `skyforge.netlab.image` to that same `Netlab.Image`.

If these diverge, preflight fails before rollout to prevent old runtime images
from being reused during quick-deploy/KNE tasks.

CI release-policy guardrail (chart/value drift check):

```bash
./scripts/check-release-policy-guardrails.sh
```

## Recommended: GHCR (OCI) chart storage

To avoid copying chart files to the k3s host, publish the chart to GHCR as an
OCI artifact and install directly from `ghcr.io`.

### Publish (dev machine)

```bash
cd skyforge

# Login (uses your existing gh auth)
gh auth refresh -h github.com -s write:packages,read:packages
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin

# Package + push
helm lint components/charts/skyforge
helm package components/charts/skyforge -d /tmp
helm push /tmp/skyforge-<chart-version>.tgz oci://ghcr.io/forwardnetworks/charts
```

This pushes to `oci://ghcr.io/forwardnetworks/charts/skyforge` using the chart
`version:` from `components/charts/skyforge/Chart.yaml`.

## Canonical prod render gate

Before promoting the local/prod profile, run the fail-closed render gate that
uses the canonical values file:

```bash
./scripts/check-chart-prod-render-contract.sh
```

This check renders `deploy/skyforge-values.yaml` with CI-only synthetic API
capabilities for optional CRD-backed integrations and placeholder values for
required secrets that are precreated in real environments. It is intended to
prove that the supported production chart contract still renders end to end
without requiring a live cluster or real credentials.

The canonical Forward contract enforced by this gate is:

- Skyforge-owned Forward core + workers
- no built-in `fwd-collector`
- `fwd-cbr-server`, `fwd-cbr-agent`, and `fwd-cbr-s3-agent` rendered as Forward runtime dependencies
- six `fwd-compute-worker` replicas
- six `fwd-search-worker` replicas
- node-role reconciler rendered for the six-node app pool

### Deploy (k3s host)

Ensure the host has `helm` and `gh` configured, then run from your local machine:

```bash
# Login (uses your existing gh auth)
gh auth refresh -h github.com -s read:packages
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin

# Copy local values/secrets to the host (use /tmp, then delete).
scp ./deploy/skyforge-values.yaml ./deploy/skyforge-secrets.yaml skyforge.local.forwardnetworks.com:/tmp/

# Install/upgrade from the host
ssh skyforge.local.forwardnetworks.com "helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  --version <chart-version> \
  -f /tmp/skyforge-values.yaml \
  -f /tmp/skyforge-secrets.yaml"

ssh skyforge.local.forwardnetworks.com "rm -f /tmp/skyforge-values.yaml /tmp/skyforge-secrets.yaml"
```

Keep host file footprint minimal: use `/tmp` and remove after the deploy.

## Required values

Populate the following before installing:

- `skyforge.hostname` (primary internal hostname for the ingress routes)
- `skyforge.domain` (email suffix for default users)
- `skyforge.gateway.addresses` (recommended for Cilium Gateway API node-IP ingress; example `[{type: IPAddress, value: "10.128.16.60"}]`)
- `skyforge.auth.mode` (`local` for dev/OSS, `oidc` for prod)
- `skyforge.gateway.additionalHostnames` exposes only the core Skyforge app/API route on alternate hostnames.
- `skyforge.gateway.additionalToolHostnames` exposes bundled tool routes such as Gitea, Coder, observability, inventory, and integration UIs on alternate hostnames. Keep this empty for public aliases that should not publish internal tools.
- When `skyforge.gateway.additionalHostnames` or `skyforge.gateway.additionalToolHostnames` is set, the managed Dex config also registers those aliases as valid OIDC redirect hosts for Skyforge and the bundled tool clients.
- If you enable Hetzner burst workers: also create the WireGuard Secret referenced by `skyforge.burst.hetzner.wireguard.hub.privateKeySecretName` (private key plus optional `peers.conf`), and verify the selected hub node IP matches `skyforge.burst.hetzner.wireguard.gatewayNodeIP`.
- If `skyforge.auth.mode=oidc`: `skyforge.dex.enabled=true`, `skyforge.dex.authMode=oidc`, and provider values under `skyforge.dex.oidc.*`
- If `secrets.create=false` (recommended): pre-create required Kubernetes
  Secrets (for example `proxy-tls`, `skyforge-session-secret`,
  `skyforge-admin-shared`, database/object-storage/Dex secrets).
- If `secrets.create=true` (local/dev compatibility): provide `secrets.items.*`
  values for passwords, TLS certs, and credentials from a local untracked file.
- If `skyforge.forwardCluster.core.nqeAssist.enabled=true`: pre-create the
  secret referenced by `skyforge.forwardCluster.core.nqeAssist.appCredentialsSecretName`
  (default `fwd-app-creds-for-nqe-assist`). This secret is separate from
  `appserver.ai_bedrock.secret_name` and should contain the Forward API
  credentials and model runtime env expected by the Harbor `fwd_nqe_assist`
  image, including `FWD_API_ACCESS_KEY`, `FWD_API_SECRET_KEY`,
  `MODEL_INSTANCE_URL`, and `QUERY_ASSIST_ADAPTER_ID`.
- If you use Netlab integrations: `secrets.items.netlab-runner-rsa` and server-pool secrets such as `secrets.items.skyforge-netlab-servers`. Server-pool values accept either a JSON array or `{"servers":[...]}`; see `deploy/skyforge-secrets.example.yaml`.

Use `--set-file` for large values (TLS, SSH keys):

```bash
helm upgrade --install skyforge ./components/charts/skyforge -n skyforge \
  --set-file secrets.items.proxy-tls.tls\.crt=certs/tls.crt \
  --set-file secrets.items.proxy-tls.tls\.key=certs/tls.key
```

## Public hostnames

For public exposure, keep the hostname model narrow:

- Use `skyforge.forwardCluster.additionalHostnames` for prospect-facing Forward/TestDrive hostnames.
- Use `skyforge.gateway.additionalHostnames` for internal-user Skyforge aliases.
- Do not put public aliases in `skyforge.gateway.additionalToolHostnames` unless the bundled tools are intentionally internet-facing and protected by an external access policy.

The embedded Skyforge frontend sets browser hardening headers on SPA/static
responses: HSTS, `nosniff`, same-origin referrer policy, camera/microphone/
geolocation deny, and `frame-ancestors 'none'`. Configure Cloudflare Access or
an equivalent identity-aware edge policy in front of public Skyforge aliases
when users should be restricted to an internal identity group.

If your TLS cert is signed by the Forward CA, install the Forward Root CA in your workstation trust store so browsers mark `https://skyforge.local.forwardnetworks.com` as secure.

When rotating TLS certs with `secrets.create=false`, update the in-cluster
secret directly (Helm should not own `proxy-tls`):

```bash
kubectl -n skyforge create secret tls proxy-tls \
  --cert=/path/to/skyforge.fullchain.pem \
  --key=/path/to/skyforge.key \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Images

Override any container image in `values.yaml` under the `images` map (for
example, to point at a private registry).
