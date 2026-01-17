# Cilium Tuning (Skyforge)

Skyforge clusters use Cilium as the CNI.

This repo keeps a minimal, repeatable set of Helm overrides to enable:

- Kube-proxy replacement (already enabled in the cluster)
- eBPF host routing (validated via `cilium status`: `Routing: Network: Native Host: BPF`)
- IPv4 BIG TCP (improves throughput for large flows)
- XDP load-balancer acceleration in `best-effort` mode (uses XDP when the NIC/driver supports it)
- Hubble disabled (reduces overhead; Hubble relay/UI removed)

## Apply (QA first, then prod)

1) Ensure your Kubernetes API tunnels are up.

2) QA:

```bash
cd skyforge-private
KUBECONFIG=.kubeconfig-skyforge-qa helm -n kube-system upgrade cilium cilium/cilium --version 1.18.6 \
  --reuse-values -f deploy/cilium-values-qa.yaml --wait --timeout 10m
KUBECONFIG=.kubeconfig-skyforge-qa kubectl -n kube-system rollout status ds/cilium --timeout=5m
KUBECONFIG=.kubeconfig-skyforge-qa kubectl -n kube-system exec ds/cilium -- cilium status --verbose | rg "IPv4 BIG TCP|Routing:|KubeProxyReplacement"
```

3) Prod:

```bash
cd skyforge-private
KUBECONFIG=.kubeconfig-skyforge helm -n kube-system upgrade cilium cilium/cilium --version 1.18.6 \
  --reuse-values -f deploy/cilium-values.yaml --wait --timeout 10m
KUBECONFIG=.kubeconfig-skyforge kubectl -n kube-system rollout status ds/cilium --timeout=5m
KUBECONFIG=.kubeconfig-skyforge kubectl -n kube-system exec ds/cilium -- cilium status --verbose | rg "IPv4 BIG TCP|Routing:|KubeProxyReplacement"
```

## Jumbo frames / MTU

Current clusters are configured with `mtu: "9000"` in `kube-system/cilium-config`.

Notes:
- This does not change host NIC MTU; it configures Cilium interfaces MTUs.
- If you see fragmentation or connectivity issues, re-check underlying network MTU and consider reducing Cilium MTU.

