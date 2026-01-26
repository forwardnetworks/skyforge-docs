# Skyforge k0s + Cilium Bootstrap (RR DNS, no kube-proxy)

This doc describes a **repeatable** cluster bootstrap path that’s “close enough” to Forward’s production conventions while meeting Skyforge’s goals:

- No `kube-proxy` (Cilium eBPF kube-proxy replacement)
- No pod-network overlay (Cilium native/direct routing)
- No single VIP required (RR DNS to node IPs works)

## Versions (as of 2026-01-26)

- k0s: `v1.34.1+k0s.1` (latest stable at the time)
- Cilium: `v1.18.5` (latest stable at the time)

If you upgrade these, keep the cluster config and scripts in sync.

## Prereqs

- 3+ nodes on the same L2 segment.
- DNS `skyforge.local.forwardnetworks.com` returns **A records** for each node IP (RR DNS).
- Ports open between nodes:
  - TCP `6443` (kube-apiserver)
  - TCP `179` if you later enable BGP (optional)
  - VXLAN (UDP `8472`) is *not* required for the cluster CNI in this model (it is still used by clabernetes for lab links).

## CIDRs

Use Forward’s defaults unless you have a reason to diverge:

- Service CIDR: `100.64.0.0/21`
- Pod CIDR: `100.70.0.0/21`

## Bootstrap flow

1) Install `k0sctl` on the first node (or your admin host).
2) Generate `k0sctl.yaml` and apply it.
3) Install Cilium:
   - `kubeProxyReplacement=true`
   - `routingMode=native` (no overlay)
   - `autoDirectNodeRoutes=true`
   - `bpf.masquerade=true`
   - `bpf.datapathMode=netkit` (requires kernel >= 6.8; Skyforge nodes run >= 6.18)
4) Deploy an ingress controller that binds `:443` on every node (RR DNS):
   - **nginx-ingress** as a **DaemonSet** with hostPorts 80/443 (Forward-aligned ops, no VIP required)
5) Deploy Skyforge Helm chart.

## Scripts

Use the scripts in `scripts/k0s/`:

- `scripts/k0s/k0sctl.yaml.example` (edit node IPs/SSH users)
- `scripts/k0s/install-k0sctl.sh`
- `scripts/k0s/install-cilium.sh`
- `scripts/k0s/install-nginx-ingress.sh`
- `scripts/k0s/install-skyforge.sh`

## Ingress notes

Skyforge ships Kubernetes `Ingress` resources targeting nginx-ingress. These replace the previous
Traefik CRD-based routing setup (IngressRoute/Middleware/TLSStore).
