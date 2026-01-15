# Skyforge k3s Cluster (skyforge-1/2/3)

This doc captures the current multi-node k3s setup for Skyforge.

## Current topology

- `skyforge-1`: k3s **server** (control-plane)
- `skyforge-2`: k3s **agent**
- `skyforge-3`: k3s **agent**

## Accessing the cluster from your workstation

Skyforge’s repo kubeconfig expects a local port-forward to the Kubernetes API.

1) Start a tunnel:

```bash
ssh -fN -L 6443:127.0.0.1:6443 root@skyforge-1
```

2) Use the repo kubeconfig:

```bash
export KUBECONFIG=skyforge-private/.kubeconfig-skyforge
kubectl get nodes -o wide
```

## Verifying cluster health (from the control-plane)

```bash
ssh root@skyforge-1 'k3s kubectl get nodes -o wide'
ssh root@skyforge-1 'k3s kubectl -n kube-system get pods -o wide'
ssh root@skyforge-1 'k3s kubectl -n skyforge get pods -o wide'
```

## Joining a new node as an agent

Run these from your workstation (or anywhere with SSH access to the nodes).

1) Fetch the k3s join token from the server:

```bash
TOKEN="$(ssh root@skyforge-1 'cat /var/lib/rancher/k3s/server/node-token')"
```

2) Check the control-plane k3s version and pin agents to **the same** version:

```bash
ssh root@skyforge-1 'k3s --version'
```

3) Install the agent on the node:

```bash
K3S_SERVER_IP="10.128.16.11"
K3S_VERSION="v1.33.6+k3s1" # replace with the control-plane version

ssh root@skyforge-2 "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='$K3S_VERSION' K3S_URL=https://$K3S_SERVER_IP:6443 K3S_TOKEN=$TOKEN INSTALL_K3S_EXEC='agent --node-name skyforge-2' sh -"
```

4) Confirm the node is Ready:

```bash
ssh root@skyforge-1 'k3s kubectl get nodes -o wide'
```

## Fixing agent version mismatch

If an agent is installed with a different k3s minor version than the server, uninstall and reinstall pinned to the server version.

```bash
ssh root@skyforge-2 '/usr/local/bin/k3s-agent-uninstall.sh || true'

TOKEN="$(ssh root@skyforge-1 'cat /var/lib/rancher/k3s/server/node-token')"
K3S_SERVER_IP="10.128.16.11"
K3S_VERSION="v1.33.6+k3s1" # replace with the control-plane version

ssh root@skyforge-2 "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='$K3S_VERSION' K3S_URL=https://$K3S_SERVER_IP:6443 K3S_TOKEN=$TOKEN INSTALL_K3S_EXEC='agent --node-name skyforge-2' sh -"
```

## Local-path PV storage on the secondary disk

Skyforge uses k3s `local-path` (host-local PVs). On all nodes we mount the secondary disk (`/dev/sdb`) at:

- `/var/lib/rancher/k3s/storage`

This keeps PV data off the root filesystem, and ensures PVs on `skyforge-2`/`skyforge-3` can be created without filling the small root partition.

To verify:

```bash
ssh root@skyforge-1 'df -h /var/lib/rancher/k3s/storage; mount | grep /var/lib/rancher/k3s/storage'
ssh root@skyforge-2 'df -h /var/lib/rancher/k3s/storage; mount | grep /var/lib/rancher/k3s/storage'
ssh root@skyforge-3 'df -h /var/lib/rancher/k3s/storage; mount | grep /var/lib/rancher/k3s/storage'
```

## Network sanity (iptables)

If a node has default iptables policies set to `DROP`, pod-to-service networking (including DNS) can break for workloads scheduled on that node.

Quick check:

```bash
ssh root@skyforge-2 'iptables -S | head -n 3'
ssh root@skyforge-3 'iptables -S | head -n 3'
```

Expected:

```
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT
```
