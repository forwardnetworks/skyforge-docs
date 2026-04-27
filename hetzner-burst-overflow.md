# Hetzner Burst Overflow with Hetzner Gateway WireGuard

This document defines the supported Skyforge pattern for Hetzner-backed burst
capacity.

## Goal

Use Hetzner as elastic `burst` capacity without changing the core cluster
model:

- Skyforge control-plane and core app workloads stay on the primary footprint
- Hetzner worker nodes join the same Kubernetes cluster as worker-only nodes
- Hetzner workers are labeled as `burst`
- a small dedicated Hetzner gateway node owns the public WireGuard listener
- one selected local Skyforge node initiates WireGuard outbound to that Hetzner gateway
- local worker nodes learn explicit routes back to the Hetzner burst CIDRs through that local node

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

Use a gateway model:

- a small Hetzner gateway node with a public IP listens for WireGuard
- one selected local Skyforge node initiates the tunnel outbound to that gateway
- Hetzner burst workers sit behind that gateway on the Hetzner private network
- the local side forwards traffic for Hetzner worker/node CIDRs
- local worker nodes install explicit routes pointing those Hetzner CIDRs at
  the local WireGuard node IP

Important detail:

- node route next-hops must be IP addresses, not DNS names
- `endpointHost` is the Hetzner gateway listener hostname or IP
- `gatewayNodeIP` is the local node-reachable IP used for `ip route replace`

## Chart Surfaces

Skyforge includes a disabled-by-default Hetzner burst config block:

- `skyforge.burst.hetzner.*`
- `skyforge.burst.hetzner.provisioningEnabled=false` keeps the Hetzner scaffold configured but disarmed
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
- local WireGuard node IP reachable from worker nodes
- Hetzner gateway hostname or public IP and UDP port
- list of cluster nodes that should receive return routes

## Worker Route Reconciliation

If local nodes need to reach Hetzner burst node CIDRs through the local
WireGuard node, enable:

- `skyforge.burst.hetzner.routeReconciler.enabled=true`

Set:

- `via`: the local WireGuard node IP on the primary cluster network
- `dev`: optional host interface name; leave empty when the next hop is a normal node IP
- `destinations`: the Hetzner burst CIDRs that need explicit routes
- `nodeSelector` or `affinity`: the local worker nodes that should carry those routes

The DaemonSet uses `hostNetwork: true` and `NET_ADMIN` so `ip route replace`
affects the node network namespace directly.

Do not target the control-plane unless that node truly needs Hetzner reachability.

## Suggested Bring-Up Order

1. Prepare the Hetzner gateway
- create a small dedicated Hetzner server using Hetzner's built-in WireGuard app image (`image=wireguard`) on `cx23`
- give it a stable public hostname or IP
- use the Hetzner WireGuard UI/bootstrap flow to configure the gateway listener on UDP `51820`
- place future burst workers behind that gateway on the Hetzner private network

2. Decide whether the environment is armed
- keep `skyforge.burst.hetzner.enabled=true` with `skyforge.burst.hetzner.provisioningEnabled=false` for scaffold-only mode
- set `skyforge.burst.hetzner.provisioningEnabled=true` only when you are ready for worker lifecycle automation to create burst capacity
- admins can also flip the runtime override from the Admin Overview UI without editing Helm values; that override is stored in Skyforge settings and takes effect on the next reconcile
- if you only need a transport tunnel (no Hetzner worker provisioning), keep `skyforge.burst.hetzner.enabled=false` and enable only `skyforge.burst.hetzner.wireguard.hub.enabled=true`

3. Prepare the local WireGuard node
- create the Secret with `private-key` and `peers.conf`
- enable `skyforge.burst.hetzner.wireguard.hub.enabled=true`
- select exactly one local node with `wireguard.hub.nodeSelector`
- set `wireguard.localAddressCIDR` to the local interface address, for example `10.31.0.1/24`
- set `wireguard.gatewayNodeIP` to the actual control-plane node IP that other workers will route toward, for example `10.128.16.73`
- set `wireguard.endpointHost` to the Hetzner gateway public hostname or IP
- configure `peers.conf` with the Hetzner gateway public key, endpoint, and `PersistentKeepalive`

4. Prepare Hetzner worker nodes
- create the private network / firewall model in Hetzner
- create worker instances intended only for `burst`
- route worker traffic through the Hetzner gateway
- verify tunnel establishment from the local Skyforge side

5. Join Hetzner workers into Kubernetes
- use the worker-only join flow for the current cluster profile
- do not join them as control-plane nodes

6. Label the Hetzner workers
- `pool-class=burst`
- `provider=hetzner`
- optional monthly cost label

7. Enable route reconciliation
- set the Hetzner burst values
- enable `routeReconciler`
- point `destinations` to the Hetzner burst CIDRs
- point `via` to the local WireGuard node IP

8. Verify

```bash
kubectl get nodes -L skyforge.forwardnetworks.com/pool-class,skyforge.forwardnetworks.com/provider
kubectl -n skyforge get ds hetzner-burst-route-reconciler
ip route | grep <hetzner-cidr>
wg show
```

## Non-Goals

This does not yet automate:

- a full dedicated Hetzner gateway lifecycle with failover
- WireGuard key generation/distribution
- worker join token distribution
- Cilium-specific route export or BGP

Those can be added later, but the first step is to make the network and pool
contract explicit and deterministic.

Reference: Hetzner documents the WireGuard app install path and API examples with `image=wireguard` and `server_type=cx23`.
