# Build & Deploy (Encore + k8s)

Skyforge favors Encore-native workflows where possible, but the production runtime is your existing k3s cluster.

## Decision (current)

- Deployment target: **self-hosted k8s** (k3s).
- Build strategy:
  - **Skyforge server**: build container images using `encore build docker ...` (Encore-native; no repo `server/Dockerfile`).
  - **Everything else** (portal, supporting services): build with Dockerfiles using the local Docker daemon.

This mirrors the typed Encore backend approach while keeping Skyforge’s k8s + S3 constraints.

## Build pipeline (recommended)

Set a registry reachable by your k3s nodes (example uses `registry.lab.local:5000`, or `localhost:5000` on single-node k3s):

```bash
SKYFORGE_REGISTRY=registry.lab.local:5000
TAG=latest
```

Build the Encore server image:
```bash
cd server
encore build docker --config infra.config.json "${SKYFORGE_REGISTRY}/skyforge-server:${TAG}" --push
```

Build the remaining images:
```bash
cd ..
docker build -f portal/Dockerfile -t "${SKYFORGE_REGISTRY}/skyforge-portal:${TAG}" portal
docker build -f docker/netbox/Dockerfile -t "${SKYFORGE_REGISTRY}/skyforge-netbox:${TAG}" .
docker build -f docker/nautobot/Dockerfile -t "${SKYFORGE_REGISTRY}/skyforge-nautobot:${TAG}" .
docker build -f docker/webhooks/Dockerfile -t "${SKYFORGE_REGISTRY}/skyforge-webhooks:${TAG}" .

docker push "${SKYFORGE_REGISTRY}/skyforge-portal:${TAG}"
docker push "${SKYFORGE_REGISTRY}/skyforge-netbox:${TAG}"
docker push "${SKYFORGE_REGISTRY}/skyforge-nautobot:${TAG}"
docker push "${SKYFORGE_REGISTRY}/skyforge-webhooks:${TAG}"
```

### Notes on Docker vs Encore

- Encore builds the server image via `encore build docker` (it does not require a `Dockerfile`).
- Non-Encore images are built with `docker build` and pushed to the registry.

If you want *everything* built Encore-style, that becomes a separate migration task (requires rethinking non-Encore components and/or how they’re containerized).

## Native Kubernetes flow (preferred)

Skyforge uses kustomize overlays as the primary deployment interface:

```bash
kubectl create namespace skyforge
kubectl apply -f k8s/traefik/helmchartconfig-plugins.yaml
kubectl apply -k k8s/overlays/k3s-traefik-secrets
```

## Switching registries (kustomize)

The k3s overlay uses `kustomize` image overrides. To point at a different registry:

```bash
cd k8s/overlays/k3s-traefik
kustomize edit set image skyforge-server=registry.lab.local/skyforge-server:latest
kustomize edit set image skyforge-portal=registry.lab.local/skyforge-portal:latest
kustomize edit set image skyforge-netbox=registry.lab.local/skyforge-netbox:latest
kustomize edit set image skyforge-nautobot=registry.lab.local/skyforge-nautobot:latest
kustomize edit set image skyforge-webhooks=registry.lab.local/skyforge-webhooks:latest
```

## Version pinning

Skyforge’s Go module pins `encore.dev v1.44.6`. Keep the build tooling pinned to the same Encore CLI version unless intentionally upgrading the stack.
