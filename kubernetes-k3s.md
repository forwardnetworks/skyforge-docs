# Kubernetes (k3s) deployment

Skyforge on k3s is now documented as a **Cilium-only** deployment.

## Goals / assumptions
- Target: k3s host(s)
- CNI/ingress: Cilium + Gateway API
- No Traefik and no flannel in the supported install path
- Secrets are managed from local-only Helm values (`deploy/skyforge-secrets.yaml`)

## 1) Install k3s with Cilium
Install k3s with flannel/traefik disabled, then install/upgrade Cilium with Gateway API enabled.

Pinned versions for Skyforge installs:
- k3s: `v1.35.4-rc2+k3s1`
- Cilium chart: `1.20.0-pre.1`

Recommended Cilium host-network settings for this environment:
- `bpf.datapathMode=netkit`
- `bpf.masquerade=true`
- `hostLegacyRouting=false`
- `kubeProxyReplacement=true`

Example k3s install flags:
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.35.4-rc2+k3s1" INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=none \
  --disable-network-policy \
  --disable-kube-proxy \
  --write-kubeconfig-mode 0644 \
  --kubelet-arg=cpu-manager-policy=static \
  --kubelet-arg=cpu-manager-reconcile-period=5s \
  --kubelet-arg=reserved-cpus=0-1" sh -
```

Example Cilium install/upgrade:
```bash
helm upgrade --install cilium cilium/cilium \
  --version 1.20.0-pre.1 \
  -n kube-system \
  -f deploy/cilium-values.yaml \
  --wait --timeout 10m
```

CPU manager note:
- `cpu-manager-policy=static` requires reserved CPUs.
- This guide reserves CPUs `0-1` for node/system workloads to avoid kubelet startup failure.
- On existing nodes switching from `none` to `static`, delete `/var/lib/kubelet/cpu_manager_state` once during migration before restarting `k3s-agent`.

Control-plane headroom note:
- On multi-node Skyforge clusters, keep explicit kubelet headroom on every k3s server/control-plane node even when you do not hard-isolate lab workloads.
- The application now prefers lower-priority, soft-placed lab scheduling over strict taints, so reserving headroom is the remaining protection against steady-state object churn and bursty lab create/delete activity.
- Recommended additional kubelet reservations on each control-plane node:
  - `--kubelet-arg=kube-reserved=cpu=750m,memory=1536Mi`
  - `--kubelet-arg=system-reserved=cpu=250m,memory=512Mi`
- Single-node or shared app/lab clusters should also raise kubelet pod density
  above the Kubernetes default of `110` pods. QA uses `maxPods: 220` with a
  `/24` pod CIDR. Production single-node installs should use a larger per-node
  pod CIDR, such as `/22`, before assigning pod CIDRs if they need materially
  more than roughly 220 pods.
- Keep these settings consistent on all control-plane nodes so API-server and controller-manager behavior stays predictable during lab churn.

Recommended k3s drop-in on each control-plane node:
```yaml
# /etc/rancher/k3s/config.yaml.d/20-skyforge-control-plane-reservations.yaml
kubelet-arg:
  - kube-reserved=cpu=750m,memory=1536Mi
  - system-reserved=cpu=250m,memory=512Mi
```

Recommended kubelet config drop-in on each single-node/shared app-lab node:
```yaml
# <k3s data-dir>/agent/etc/kubelet.conf.d/10-skyforge-max-pods.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: 220
```

Apply + verify:
```bash
sudo MAX_PODS=220 RESTART=true ./scripts/configure-k3s-control-plane-reservations.sh
kubectl get node "$(hostname)" -o jsonpath='{.status.allocatable.cpu}{" "}{.status.allocatable.memory}{" pods="}{.status.allocatable.pods}{"\n"}'
```

API Priority and Fairness note:
- Enable `skyforge.apiPriorityAndFairness.create=true` in the chart on multi-node clusters that run churn-heavy lab controllers.
- This does not reduce object churn by itself; it gives Skyforge platform service accounts guaranteed apiserver concurrency while pushing meshnet/KubeVirt/CDI/controller traffic into a lower-priority queue.
- APF cannot distinguish lab orchestration requests from platform orchestration requests when both use the same Kubernetes client identity. If you need stronger separation later, split lab orchestration onto a dedicated service account/client path.

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
