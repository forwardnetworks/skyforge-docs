# Cilium performance notes (Skyforge dev)

Skyforge runs VM-heavy workloads (vrnetlab/QEMU, IOL, etc.). Cilium is configured to optimize for:

- Low datapath overhead (kube-proxy replacement + eBPF)
- High connection churn (collector↔devices, websockets, UI)
- High throughput (artifact downloads, large CLI outputs)

## Files

- `deploy/cilium-values.before.yaml`: captured `helm -n kube-system get values cilium --all` before performance tuning.
- `deploy/cilium-values.yaml`: Helm overlay applied on top of the existing Cilium release.

## Current tuning (overlay)

- `routingMode: native` + `autoDirectNodeRoutes: true`
  - Nodes are L2-adjacent, so we avoid VXLAN tunnel overhead.
- `ipv4NativeRoutingCIDR: 100.70.0.0/16`
  - Matches the cluster-pool Pod CIDR on this cluster.
- `socketLB.enabled: true`
  - Reduce service load balancing overhead.
- `enableIPv4BIGTCP: true`
  - Improve throughput/CPU efficiency on modern kernels.
- `l2NeighDiscovery.enabled: true`
  - Improves ARP stability; when IPv6 dual-stack is enabled later, this also helps NDP.

## Apply / rollback

Apply:

```sh
export KUBECONFIG=skyforge-private/.kubeconfig-skyforge
helm -n kube-system upgrade --install cilium cilium/cilium -f skyforge-private/deploy/cilium-values.yaml --wait --timeout 10m
```

Rollback (use the captured baseline values):

```sh
export KUBECONFIG=skyforge-private/.kubeconfig-skyforge
helm -n kube-system upgrade --install cilium cilium/cilium -f skyforge-private/deploy/cilium-values.before.yaml --wait --timeout 10m
```

## IPv6 (dual-stack) plan

We can enable IPv6 in Cilium once k3s is configured for dual-stack PodCIDR/ServiceCIDR.
Until then, IPv6 remains off in the overlay to avoid mismatched control-plane networking.

### Current reality check

On the Skyforge nodes today, IPv6 is enabled at the kernel level, but interfaces only have **link-local** IPv6
addresses (no routed/global IPv6). That means:

- NDP exists on-link, but there is no IPv6 underlay to route “real” IPv6 traffic between nodes.
- To run dual-stack pods (IPv4+IPv6), we must first provision a routed IPv6 underlay (or IPv6 L2 adjacency with
appropriate addressing) and then enable k3s dual-stack CIDRs.

### Dual-stack (IPv4+IPv6) enablement checklist

Skyforge can run dual-stack on an IPv4-only underlay by using a ULA IPv6 underlay (for example, `fd00:.../64`) as long
as all nodes are L2-adjacent and can reach each other over IPv6. The minimum requirements are:

1. **IPv6 underlay on every node interface** (beyond link-local): assign a stable IPv6 address (ULA or global) on the
   primary node interface (e.g. `ens33`) and ensure the addresses are reachable between nodes.
2. **k3s dual-stack cluster/service CIDRs**: configure k3s with dual-stack `cluster-cidr` (pods) and `service-cidr`
   (ClusterIPs). Kubernetes validates Service ClusterIPs against `service-cidr`, so Cilium alone cannot “fake” this.
3. **Enable IPv6 in Cilium**: set `ipv6.enabled=true` and set `ipv6NativeRoutingCIDR` to match the pod IPv6 CIDR used by
   Cilium IPAM (cluster-pool). Keep `l2NeighDiscovery.enabled=true` for NDP.

Note: changing `cluster-cidr` / `service-cidr` on an existing k3s cluster is typically disruptive and may require a
cluster rebuild. For dev, this can be acceptable; for production, plan a migration.

### Dual-stack Cilium overlay

This repo includes `skyforge-private/deploy/cilium-values-dualstack.yaml` which:

- Enables `ipv6.enabled`
- Sets `ipv6NativeRoutingCIDR` (pods) to `fd00::/104`
- Enables eBPF masquerade (`bpf.masquerade=true`) to reduce reliance on iptables
- Requires k8s PodCIDRs (`k8s.requireIPv4PodCIDR/requireIPv6PodCIDR=true`) to keep routing deterministic
