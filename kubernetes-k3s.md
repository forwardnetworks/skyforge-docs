# Kubernetes (k3s) deployment

Skyforge on k3s is now documented as a **Cilium-only** deployment.

## Goals / assumptions
- Target: k3s host(s)
- CNI/ingress: Cilium + Gateway API
- No Traefik and no flannel in the supported install path
- Secrets are managed from local-only Helm values (`deploy/skyforge-secrets.yaml`)

## 1) Install k3s with Cilium
Install k3s with flannel/traefik disabled, then install/upgrade Cilium with Gateway API enabled.

Example k3s install flags:
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=none \
  --disable-network-policy \
  --disable-kube-proxy \
  --write-kubeconfig-mode 0644" sh -
```

Example checks:
```bash
kubectl get nodes
kubectl -n kube-system get pods -o wide | rg -i 'cilium|envoy'
kubectl get gatewayclass
kubectl -n kube-system get helmchart,helmchartconfig | rg -i 'traefik|flannel' || true
ls /var/lib/rancher/k3s/agent/etc/cni/net.d/
```

## 2) Ensure DNS + TLS hostname are correct
- Set `skyforge.hostname` in `deploy/skyforge-values.yaml`.
- Ensure the hostname resolves to your gateway entry IP.
- Ensure cert SANs match the hostname and place cert/key in `deploy/skyforge-secrets.yaml` (`proxy-tls`).

## 3) Prepare values + secrets
```bash
$EDITOR deploy/skyforge-values.yaml
```

Pre-create required Kubernetes secrets in namespace `skyforge` and use
`secrets.create=false` in values. Keep secret literals out of tracked files.

## 4) Apply chart
```bash
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  --set secrets.create=false \
  -f deploy/skyforge-values.yaml \
```

## 5) Validate Cilium-native ingress
```bash
kubectl -n skyforge get gateway,httproute
kubectl -n kube-system get pods | rg -i 'traefik|flannel'
curl -k https://<hostname>/status/summary
```

Expected:
- Gateway + HTTPRoute objects are programmed
- no active Traefik/flannel workloads

## Storage
- Skyforge uses S3-compatible object storage; chart defaults to in-cluster `s3gw`.
- See `docs/backups.md` and `docs/kubernetes-backup.md` for backup flows.

## Backup / restore
See `docs/kubernetes-backup.md`.
