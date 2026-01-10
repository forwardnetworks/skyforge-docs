# Build & Deploy (Encore + k8s)

Skyforge favors Encore-native workflows where possible, but the production runtime is your existing k3s cluster.

## Decision (current)

- Deployment target: **self-hosted k8s** (k3s).
- Build strategy:
  - **Skyforge server**: build container images using `encore build docker ...` (Encore-native; no repo `server/Dockerfile`).
  - **Everything else** (portal, supporting services): build with Dockerfiles using the local Docker daemon.

This mirrors the typed Encore backend approach while keeping Skyforge’s k8s + S3 constraints.

## Build pipeline (recommended)

Set a registry reachable by your k3s nodes (private GHCR):

```bash
SKYFORGE_REGISTRY=ghcr.io/forwardnetworks
TAG=latest
```

For private GHCR, ensure you can push from your build machine:
```bash
gh auth refresh -h github.com -s read:packages,write:packages
gh auth token | docker login ghcr.io -u <github-user> --password-stdin
```

Build the Encore server image (k3s runs `linux/amd64`):
```bash
cd server
# Ensure the LabPP CLI code is bundled into the server image.
rsync -a --delete ../fwd/ ./fwd/
encore build docker --arch amd64 --config infra.config.json "${SKYFORGE_REGISTRY}/skyforge-server:${TAG}" --push
```

Go toolchain note: `server/go.mod` pins `toolchain go1.26rc1`. If your local Go version differs, the Go tool will fetch/use 1.26rc1 automatically (or set `GOTOOLCHAIN=go1.26rc1`).

Build the remaining images (`linux/amd64` from Apple Silicon requires Buildx):
```bash
cd ..
docker buildx build --platform linux/amd64 --push -f portal/Dockerfile -t "${SKYFORGE_REGISTRY}/skyforge-portal:${TAG}" portal
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
