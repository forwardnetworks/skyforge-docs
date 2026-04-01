# Hetzner Burst Overflow with Outbound WireGuard

This document defines the intended Skyforge pattern for Hetzner-backed burst
workers.

## Goal

Use Hetzner as elastic `burst` capacity without changing the core cluster
model:

- Skyforge control-plane and core app workloads stay on the primary footprint
- Hetzner worker nodes join the same Kubernetes cluster as worker-only nodes
- Hetzner workers are labeled as `burst`
- WireGuard is initiated outbound from the Hetzner side
- one selected local hub node terminates the WireGuard interface
- local worker nodes learn explicit routes back to the Hetzner burst CIDRs through that hub node

This keeps the existing scheduling model intact while making burst capacity a
provider-specific worker pool instead of a second cluster.

## Supported Model

### Cluster role

Hetzner nodes are worker-only and should be labeled:

```bash
kubectl label node <node-name> \
  skyforge.forwardnetworks.com/pool-class=burst \
  skyforge.forwardnetworks.com/provider=hetzner \
  --overwrite
```

Optional cost label:

```bash
kubectl label node <node-name> \
  skyforge.forwardnetworks.com/monthly-node-cost-cents=<cents> \
  --overwrite
```

### WireGuard topology

Use a hub-and-spoke style layout:

- `skyforge.local.forwardnetworks.com` (or a dedicated local gateway host)
  listens for WireGuard
- Hetzner workers initiate the tunnel outbound to that endpoint
- local nodes do not initiate toward Hetzner
- the local side forwards traffic for Hetzner worker/node CIDRs
- local worker nodes install explicit routes pointing those Hetzner CIDRs at
  the local WireGuard gateway IP

Important detail:

- node route next-hops must be IP addresses, not DNS names
- `endpointHost` is for the Hetzner WireGuard peer
- `gatewayNodeIP` is the local node-reachable IP used for `ip route replace`

## Chart Surfaces

Skyforge now includes a disabled-by-default Hetzner burst config block:

- `skyforge.burst.hetzner.*`
- `skyforge.burst.hetzner.wireguard.hub.*`
- `skyforge.burst.hetzner.routeReconciler.*`

Example values are provided in:

- `deploy/examples/values-hetzner-burst.yaml`

The route reconciler is implemented as a privileged host-network DaemonSet.
It continuously enforces explicit routes on selected cluster nodes.

## Required Inputs

Before enabling this path, define these values:

- Hetzner API token secret
  - Kubernetes secret: `skyforge-hetzner-burst`
  - key: `api-token`
- Hetzner network/node CIDRs
- local WireGuard gateway IP reachable from worker nodes
- WireGuard endpoint hostname and UDP port
- list of cluster nodes that should receive return routes

## Worker Route Reconciliation

If local nodes need to reach Hetzner burst node CIDRs through the WireGuard
hub, enable:

- `skyforge.burst.hetzner.routeReconciler.enabled=true`

Set:

- `via`: the local gateway node IP on the primary cluster network
- `dev`: optional host interface name; leave empty when the next hop is a normal node IP
- `destinations`: the Hetzner burst CIDRs that need explicit routes
- `nodeSelector` or `affinity`: the local worker nodes that should carry those routes

The DaemonSet uses `hostNetwork: true` and `NET_ADMIN` so `ip route replace`
affects the node network namespace directly.

Do not target the control-plane unless that node truly needs Hetzner reachability.

## Suggested Bring-Up Order

1. Prepare the local WireGuard gateway
- create the Secret with `private-key` and optional `peers.conf`
- enable `skyforge.burst.hetzner.wireguard.hub.enabled=true`
- select exactly one hub node with `wireguard.hub.nodeSelector`
- set `wireguard.localAddressCIDR` to the hub interface address, for example `10.31.0.1/24`
- set `wireguard.gatewayNodeIP` to the actual control-plane node IP that other workers will route toward, for example `10.128.16.73`
- enable IP forwarding on that hub

2. Prepare Hetzner worker nodes
- create the private network / firewall model in Hetzner
- create worker instances intended only for `burst`
- install WireGuard and configure outbound peers to
  `skyforge.local.forwardnetworks.com:<port>`
- verify tunnel establishment from the Hetzner side

3. Join Hetzner workers into Kubernetes
- use the worker-only join flow for the current cluster profile
- do not join them as control-plane nodes

4. Label the Hetzner workers
- `pool-class=burst`
- `provider=hetzner`
- optional monthly cost label

5. Enable route reconciliation
- set the Hetzner burst values
- enable `routeReconciler`
- point `destinations` to the Hetzner burst CIDRs
- point `via` to the local gateway node IP

6. Verify

```bash
kubectl get nodes -L skyforge.forwardnetworks.com/pool-class,skyforge.forwardnetworks.com/provider
kubectl -n skyforge get ds hetzner-burst-route-reconciler
ip route | grep <hetzner-cidr>
```

## Non-Goals

This does not yet automate:

- Hetzner server creation from the API token
- WireGuard key generation/distribution
- worker join token distribution
- Cilium-specific route export or BGP

Those can be added later, but the first step is to make the network and pool
contract explicit and deterministic.
