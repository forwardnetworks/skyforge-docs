# Docker-based image builds for k3s (Skyforge)

Goal: build Skyforge images using the local Docker daemon (including `encore build docker` for the server), push them to the registry used by k3s, and optionally roll deployments.

## How it works
- Source: local working tree (monorepo with `server/`, `portal/`, and `k8s/`).
- Builder: local Docker daemon.
- Server image: built with Encore (`encore build docker ...`) because Encore owns the build pipeline.
- Registry: a node-local registry (default `127.0.0.1:5000`). For multi-node setups, use a hostname such as `registry.lab.local:5000`.

## Prereqs (once per cluster)
1) Registry running:
```bash
kubectl apply -k k8s/infra/registry
```

2) k3s nodes allow pulling from the HTTP registry by adding an entry to `/etc/rancher/k3s/registries.yaml` (replace the host if you use `registry.lab.local:5000`):
```yaml
mirrors:
  "127.0.0.1:5000":
    endpoint:
      - "http://127.0.0.1:5000"
```
Then restart k3s:
```bash
sudo systemctl restart k3s
```

## Build images
Set a registry reachable by your k3s nodes:
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

## Notes
- Builds use `TAG` (default `latest`) and `SKYFORGE_REGISTRY` (default `127.0.0.1:5000` on single-node).
- This builds from your local working tree. Commit/push is separate.
- Default `SKYFORGE_REGISTRY` is `127.0.0.1:5000` so the resulting images match the k3s overlay image references (single-node).

## Optional: pull images from outside the cluster
If you want to verify the registry from outside the cluster without opening `:5000`, Traefik can expose it at:
- `https://<SKYFORGE_HOSTNAME>/v2/`

Example:
```bash
curl -k https://<hostname>/v2/
```

Notes:
- The registry TLS is self-signed by default; use `-k` for curl, and install the CA cert on clients if you want full trust.
