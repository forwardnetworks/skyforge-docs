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
