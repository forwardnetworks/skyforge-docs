# Kubernetes (k3s) deployment

This repo includes a Kubernetes manifest set under `k8s/kompose/` that mirrors the current k3s stack.

## Goals / assumptions
- Target: a host running **k3s**
- Edge: Traefik is the only edge (TLS + routing + SSO gate to Skyforge Server).
- No *edge* nginx in Kubernetes: Traefik is the only edge. We still run small internal `nginx` helper pods where upstream apps require it (e.g., Nautobot static and `/logout` wiring).
- Secrets: do **not** commit secrets; create Kubernetes Secrets from `k8s/overlays/k3s-traefik-secrets/secrets/` and `k8s/overlays/k3s-traefik-secrets/certs/`

## 1) Install k3s
Follow your standard k3s process. Minimal example:
```bash
curl -sfL https://get.k3s.io | sh -
sudo kubectl get nodes
```

## 2) Ensure DNS + TLS hostname are correct
Several components validate the public hostname and TLS certificate (for example, the object storage console redirect URL).

- Pick the public hostname (example): `skyforge.your-domain.local` and set it in `config.env`.
- Ensure it resolves to the k3s ingress/VM IP from:
  - your workstation browser
  - the k3s cluster nodes/pods (cluster DNS should resolve it normally)
- Ensure `./certs/skyforge.crt` has a SAN for that hostname

## 3) Prepare secrets
Populate local secret files under `k8s/overlays/k3s-traefik-secrets/secrets/` and TLS certs under `k8s/overlays/k3s-traefik-secrets/certs/`.

Required inputs (gitignored):
- `k8s/overlays/k3s-traefik-secrets/secrets/*` (LDAP, DB passwords, admin passwords, etc.)
- `./certs/skyforge.crt` + `./certs/skyforge.key` (for `proxy-tls`)

Note: the secrets overlay reads from local files. If you are skipping optional integrations, create empty placeholder files so `kustomize` can render the Secret manifests.

## 4) Apply manifests
Enable the required Traefik plugin (rewritebody) on k3s (required for `/code` and `/minio-console` subpaths):
```bash
kubectl apply -f k8s/traefik/helmchartconfig-plugins.yaml
```

Validate Traefik CRDs/config/service:
```bash
kubectl -n kube-system get deploy traefik
kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik
```

Optional NodePort exposure (forces `30080/30443` and also enables the rewritebody plugin):
```bash
kubectl apply -f k8s/traefik/helmchartconfig-nodeport.yaml
```

Recommended (k3s + Traefik overlay with secrets):
```bash
cp k8s/overlays/k3s-traefik-secrets/config.env.example k8s/overlays/k3s-traefik-secrets/config.env
# Edit config.env to match your hostname, admin email, and branding.
kubectl apply -k k8s/overlays/k3s-traefik-secrets
```


Optional overlays:
- Longhorn storage class (sets all PVCs `storageClassName: longhorn`): `kubectl apply -k k8s/overlays/k3s-longhorn`
- LoadBalancer exposure (MetalLB/cloud LB): use Traefik’s Service config (k3s HelmChartConfig)

Notes:
- `k8s/overlays/k3s-traefik` uses Traefik CRDs (`IngressRoute`, `Middleware`). On k3s they are typically installed with Traefik.

Base (raw kompose output):
```bash
kubectl -n skyforge apply -f k8s/kompose/
```

Warning: applying raw `k8s/kompose/` can overwrite images (e.g. reset `skyforge-server` to `:latest`) and break the overlay’s local-registry wiring. Prefer the overlay unless you are intentionally regenerating kompose output.

If Postgres was already initialized and you need to reprovision DBs/users:
```bash
kubectl -n skyforge delete job/db-provision --ignore-not-found
kubectl -n skyforge apply -f k8s/kompose/db-provision-job.yaml
```

## 5) Build/publish required images
Kubernetes can’t see images you built on your workstation unless you:
- push them to a registry reachable by your k3s nodes, or
- import/load them onto every node

For build commands and registry setup, see `docs/kubernetes-build.md`.

Traefik is the only edge ingress in the k3s overlay.

## 6) Smoke test
From any machine with `kubectl` access:
```bash
kubectl -n skyforge get pods
curl -k https://<hostname>/data/platform-health.json
```

## Edge exposure (Traefik)
By default, k3s installs Traefik and exposes it as a Service (often `LoadBalancer` via k3s/klipper-lb).

For Skyforge, we run Traefik in `hostNetwork` mode so the node listens on `:80` and `:443`.
Point DNS for your Skyforge hostname at that node’s IP.

Ensure the host firewall allows inbound `80/tcp` and `443/tcp`.

Quick check:
```bash
curl -k https://<hostname>/data/platform-health.json
```

## TLS
See `docs/kubernetes-tls.md`.

## Storage
See `docs/kubernetes-storage.md`.

## Builds (Kubernetes-native)
See `docs/kubernetes-build.md`.

## Backup / restore
See `docs/kubernetes-backup.md` for a single-node `local-path` backup/restore checklist.

## Git bootstrap (k8s)
Use your local git client to push into the in-cluster Gitea once it is up:
```bash
git remote add gitea http://<gitea-host>/skyforge/skyforge.git
git push gitea HEAD:main
```

## Hostname config (k8s)
`k8s/kompose/skyforge-config-configmap.yaml` is the default.
Update it for your environment:
- `SKYFORGE_HOSTNAME`
- `SKYFORGE_HOSTNAME`
- `GITEA_ROOT_URL`
- `MINIO_BROWSER_REDIRECT_URL`
