# Build & Deploy (Encore + k8s)

Skyforge favors Encore-native workflows where possible, but the production runtime is your existing k3s cluster.

## Decision (current)

- Deployment target: **self-hosted k8s** (k3s).
- Build strategy:
  - **Skyforge server**: build container images using `encore build docker ...` (Encore-native; no repo `server/Dockerfile`).
  - **UI**: build the TanStack portal with Vite and embed it into the server image (served by Encore; no separate Nginx portal container).
  - **Everything else** (supporting services): build with Dockerfiles using the local Docker daemon.

This mirrors the typed Encore backend approach while keeping Skyforge’s k8s + S3 constraints.

## Build pipeline (recommended)

Set a registry reachable by your k3s nodes (private GHCR):

```bash
SKYFORGE_REGISTRY=ghcr.io/forwardnetworks
TAG=latest
```

### One-command build (recommended)

Use the repo script to avoid shipping a server image with stale embedded UI assets:

```bash
./scripts/build-push-skyforge-server.sh --registry "${SKYFORGE_REGISTRY}" --tag "${TAG}"
```

Recommended hardened invocation (timeouts + automatic diagnostics on failure):

```bash
./scripts/build-push-skyforge-server.sh \
  --registry "${SKYFORGE_REGISTRY}" \
  --tag "${TAG}" \
  --timeout-seconds 1800
```

Failure diagnostics are written under:

```bash
artifacts/encore-build/<timestamp>-<tag>/
```

The script now:
- starts a dedicated Encore daemon for the build run,
- enforces per-image timeout boundaries,
- captures Encore trace + host diagnostics on timeout/failure,
- auto-builds from a standalone mirrored server checkout when the server repo is a submodule gitfile (prevents known Encore `.git` stat-loop hangs),
- verifies pushed image manifests before reporting success.

For private GHCR, ensure you can push from your build machine:
```bash
gh auth refresh -h github.com -s read:packages,write:packages
gh auth token | docker login ghcr.io -u <github-user> --password-stdin
```

Build the Encore server images (k3s runs `linux/amd64`):
```bash
cd server
# Build the embedded TanStack frontend first.
cd ../portal-tanstack
pnpm install
pnpm build
cd ../server

# Ensure the LabPP CLI code is bundled into the server image.
rsync -a --delete ../fwd/ ./fwd/
# API image (excludes worker subscriptions).
encore build docker --arch amd64 --config ../charts/skyforge/files/infra.api.config.json \
  --services=skyforge,health,storage \
  "${SKYFORGE_REGISTRY}/skyforge-server:${TAG}" --push

# Worker image (includes PubSub subscriptions).
encore build docker --arch amd64 --config infra.config.json \
  --services=skyforge,health,storage,worker \
  "${SKYFORGE_REGISTRY}/skyforge-server:${TAG}-worker" --push
```

If your GHCR token is stored on disk, you can also let the script perform login:

```bash
./scripts/build-push-skyforge-server.sh \
  --registry "${SKYFORGE_REGISTRY}" \
  --tag "${TAG}" \
  --github-token-file /home/<user>/github.token \
  --standalone-mirror auto
```

Go toolchain note: `server/go.mod` pins `toolchain go1.26rc2`. If your local Go version differs, the Go tool will fetch/use 1.26rc2 automatically (or set `GOTOOLCHAIN=go1.26rc2`).

Build the remaining images (`linux/amd64` from Apple Silicon requires Buildx):
```bash
cd ..
docker buildx build --platform linux/amd64 --push -f docker/netbox/Dockerfile -t "${SKYFORGE_REGISTRY}/skyforge-netbox:${TAG}" .
docker buildx build --platform linux/amd64 --push -f docker/nautobot/Dockerfile -t "${SKYFORGE_REGISTRY}/skyforge-nautobot:${TAG}" .
```

For private GHCR, the k3s namespace must have an image pull secret:
```bash
kubectl -n skyforge create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=<github-user> \
  --docker-password="$(gh auth token)" \
  --docker-email=<github-user>@users.noreply.github.com

kubectl -n skyforge patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"ghcr-pull"}]}'
```

### Notes on Docker vs Encore

- Encore builds the server image via `encore build docker` (it does not require a `Dockerfile`).
- Non-Encore images are built with `docker build` and pushed to the registry.

If you want *everything* built Encore-style, that becomes a separate migration task (requires rethinking non-Encore components and/or how they’re containerized).

## Native Kubernetes flow (preferred)

Skyforge ships a Helm chart and publishes it to GHCR as an OCI artifact:

```bash
gh auth refresh -h github.com -s read:packages
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin

scp ./deploy/skyforge-values.yaml ./deploy/skyforge-secrets.yaml skyforge.local.forwardnetworks.com:/tmp/

ssh skyforge.local.forwardnetworks.com "helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  --version <chart-version> \
  -f /tmp/skyforge-values.yaml \
  -f /tmp/skyforge-secrets.yaml"

ssh skyforge.local.forwardnetworks.com "rm -f /tmp/skyforge-values.yaml /tmp/skyforge-secrets.yaml"
```

## Version pinning

Skyforge’s Go module pins `encore.dev v1.44.6`. Keep the build tooling pinned to the same Encore CLI version unless intentionally upgrading the stack.
