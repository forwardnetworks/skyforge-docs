# Skyforge k3s Cluster (skyforge-1/2/3)

This doc captures the current multi-node k3s setup for Skyforge.

## Current topology

- `skyforge-1`: k3s **server** (control-plane/etcd/worker)
- `skyforge-2`: k3s **server** (control-plane/etcd/worker)
- `skyforge-3`: k3s **server** (control-plane/etcd/worker)

## Networking

- CNI: Cilium (kube-proxy disabled)
- Pod CIDR: `100.64.0.0/16`
- Service CIDR: `100.65.0.0/16`
- Kubernetes API VIP: `10.128.16.11` (kube-vip on control-plane nodes)

## Storage

Skyforge uses Longhorn for HA PVCs. See `docs/storage-longhorn.md`.

On all nodes, the secondary disk (`/dev/sdb1`) is mounted at:

- `/var/lib/longhorn`

To keep the root disk small and avoid DiskPressure, we bind-mount Kubernetes data under:

- `/var/lib/rancher` → `/var/lib/longhorn/rancher`

## Accessing the cluster from your workstation

Skyforge’s repo kubeconfig expects a local port-forward to the Kubernetes API.

Notes:
- Skyforge’s user-facing URL can be round-robin across nodes (Traefik runs on all nodes).
- The Kubernetes API endpoint used by agents (`K3S_URL`) should be a stable VIP/LB (not round-robin),
  or you risk agents pinning to a dead/rotated IP.

1) Start a tunnel:

```bash
ssh -fN -L 6443:127.0.0.1:6443 ubuntu@skyforge-1.local.forwardnetworks.com
```

2) Use the repo kubeconfig:

```bash
export KUBECONFIG=skyforge-private/.kubeconfig-skyforge
kubectl get nodes -o wide
```

## Verifying cluster health (from the control-plane)

```bash
ssh ubuntu@skyforge-1.local.forwardnetworks.com 'sudo k3s kubectl get nodes -o wide'
ssh ubuntu@skyforge-1.local.forwardnetworks.com 'sudo k3s kubectl -n kube-system get pods -o wide'
ssh ubuntu@skyforge-1.local.forwardnetworks.com 'sudo k3s kubectl -n skyforge get pods -o wide'
```

## Joining a new node as a server

Run these from your workstation (or anywhere with SSH access to the nodes).

1) Fetch the k3s join token from the server:

```bash
TOKEN="$(ssh ubuntu@skyforge-1.local.forwardnetworks.com 'sudo cat /var/lib/rancher/k3s/server/node-token')"
```

2) Check the control-plane k3s version and pin the new node to **the same** version:

```bash
ssh ubuntu@skyforge-1.local.forwardnetworks.com 'sudo k3s --version'
```

3) Install the server on the new node:

```bash
# IMPORTANT: use a stable control-plane address (VIP/LB), not round-robin DNS.
# In prod, we typically use the API VIP `10.128.16.11` (or a DNS name that
# resolves to that VIP).
K3S_SERVER_HOST="10.128.16.11"
K3S_VERSION="v1.35.0+k3s1" # replace with the control-plane version

ssh ubuntu@<new-node> "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='$K3S_VERSION' K3S_URL=https://$K3S_SERVER_HOST:6443 K3S_TOKEN=$TOKEN sh -"
```

4) Confirm the node is Ready:

```bash
ssh ubuntu@skyforge-1.local.forwardnetworks.com 'sudo k3s kubectl get nodes -o wide'
```

## Fixing agent version mismatch

If an agent is installed with a different k3s minor version than the server, uninstall and reinstall pinned to the server version.

```bash
ssh ubuntu@<new-node> 'sudo /usr/local/bin/k3s-uninstall.sh || true'

TOKEN="$(ssh ubuntu@skyforge-1.local.forwardnetworks.com 'sudo cat /var/lib/rancher/k3s/server/node-token')"
K3S_SERVER_HOST="10.128.16.11"
K3S_VERSION="v1.35.0+k3s1" # replace with the control-plane version

ssh ubuntu@<new-node> "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='$K3S_VERSION' K3S_URL=https://$K3S_SERVER_HOST:6443 K3S_TOKEN=$TOKEN sh -"
```

## Network sanity (iptables)

If a node has default iptables policies set to `DROP`, pod-to-service networking (including DNS) can break for workloads scheduled on that node.

Quick check:

```bash
ssh ubuntu@skyforge-2.local.forwardnetworks.com 'sudo iptables -S | head -n 3'
ssh ubuntu@skyforge-3.local.forwardnetworks.com 'sudo iptables -S | head -n 3'
```

Expected:

```
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT
```
