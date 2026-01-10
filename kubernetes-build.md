# Docker-based image builds for k3s (Skyforge)

Goal: build Skyforge images using the local Docker daemon (including `encore build docker` for the server), push them to a registry used by k3s, and optionally roll deployments.

## How it works
- Source: local working tree (monorepo with `server/`, `portal/`, and `k8s/`).
- Builder: local Docker daemon.
- Server image: built with Encore (`encore build docker ...`) because Encore owns the build pipeline.
- Registry: **recommended** `ghcr.io/forwardnetworks` (private GHCR).

## Recommended: Private GHCR (forwardnetworks)
On the build machine (once):
```bash
gh auth refresh -h github.com -s read:packages,write:packages
gh auth token | docker login ghcr.io -u <github-user> --password-stdin
```

On the k3s cluster (once per namespace), create a pull secret:
```bash
kubectl -n skyforge create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=<github-user> \
  --docker-password="$(gh auth token)" \
  --docker-email=<github-user>@users.noreply.github.com

kubectl -n skyforge patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"ghcr-pull"}]}'
```

## Build images
Set a registry reachable by your k3s nodes:
```bash
SKYFORGE_REGISTRY=ghcr.io/forwardnetworks
TAG=latest
```

Build the Encore server image (k3s is `linux/amd64`):
```bash
cd server
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

## Notes
- Builds use `TAG` (default `latest`) and `SKYFORGE_REGISTRY`.
- This builds from your local working tree. Commit/push is separate.
- For private GHCR, ensure the namespace has an `imagePullSecret` (example above).
- Syslog and SNMP trap ingest use standard collectors (Vector/Telegraf) and do not require building extra images.
