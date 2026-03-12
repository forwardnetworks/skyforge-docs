# Hetzner Hybrid Control Plane with On-Prem HPE Workers

## Summary

This note captures the intended hybrid production model once two on-prem HPE
DL380 Gen9 servers become available.

The target design is:

- Skyforge control plane and public ingress stay in Hetzner
- a minimal Hetzner app pool keeps core platform workloads cloud-side
- two HPE hosts join as worker-only `k3s` agents
- heavy lab workloads prefer the on-prem workers first
- Hetzner burst workers remain available as overflow capacity

This keeps internet-facing access and future expansion simple while using the
large on-prem servers for the expensive lab and NOS workload profile.

## Why This Model

This is the preferred tradeoff for Skyforge because it preserves:

- stable public ingress and API access in Hetzner
- simple customer-facing expansion later
- low baseline cloud cost
- high local compute density for heavy lab workloads
- one cluster model instead of split-brain orchestration

Do not move control-plane nodes on-prem in this design.

## Terraform Scope

The current Hetzner Terraform root should continue to manage only Hetzner
resources.

It should not try to provision or manage the on-prem HPE servers directly.

Terraform remains responsible for:

- Hetzner control-plane nodes
- Hetzner app worker pool
- Hetzner burst pool
- Hetzner load balancers
- Hetzner networking and pinned `kube-hetzner` cluster configuration

The on-prem workers are a post-provision cluster join step.

## Target Pool Layout

- `control`
  - Hetzner control-plane nodes
- `app`
  - Hetzner app workers for `skyforge-server`, worker, DB, Redis, Git, object
    storage access, and observability
- `onprem-lab`
  - the two HPE hosts
- `burst`
  - Hetzner autoscaled overflow capacity

## Networking Constraint

The on-prem HPE hosts will have internet access but sit behind NAT, and router
configuration is not assumed to be available.

That makes host-initiated WireGuard the correct first design.

## Recommended Connectivity Model

Use a routed L3 model:

- Cilium routing mode remains `native`
- a dedicated Hetzner WireGuard gateway VM acts as the public VPN hub
- each HPE worker runs WireGuard directly on the host
- each HPE worker initiates outbound to the Hetzner gateway using
  `PersistentKeepalive`
- each HPE worker joins `k3s` using its WireGuard address as the node IP

This avoids any dependency on router changes or inbound port-forwarding on the
on-prem side.

## Why WireGuard on the Hosts

WireGuard directly on the HPE hosts is the simplest correct answer because:

- the hosts can dial out through NAT
- WireGuard tolerates NAT well in that direction
- the Kubernetes node can advertise its stable tunnel IP
- Kubernetes and Cilium then operate over a clean routed transport

Do not terminate this VPN on the Hetzner control-plane nodes if it can be
avoided. Use a small dedicated gateway VM instead.

## Recommended Network Shape

- Hetzner VPN gateway:
  - public IP
  - `wg0` address like `10.250.0.1/24`
- HPE worker 1:
  - `wg0` address like `10.250.0.11/32`
- HPE worker 2:
  - `wg0` address like `10.250.0.12/32`

Each HPE node should join `k3s` using:

- `--node-ip=<wg0-ip>`

This makes the tunnel IP the Kubernetes node identity.

## Transport and Routing Requirements

Required between Hetzner and the on-prem workers:

- stable node-to-node reachability over WireGuard
- routed pod traffic across sites
- sane MTU, likely reduced from default
- firewall allowance for:
  - k3s node traffic
  - kubelet traffic
  - Cilium dataplane traffic
  - WireGuard UDP

Use conservative MTU values first and prove pod-to-pod and service-to-pod
traffic before attaching production lab workloads.

## Hetzner Template Changes

The existing Hetzner profile should change in these ways:

1. keep 3 control-plane nodes in Hetzner
2. shrink the default cloud-side app pool to a single lightweight node
3. keep the burst Hetzner nodepool for overflow
4. tighten kube API and SSH source CIDRs
5. keep `cilium_routing_mode = "native"`
6. add a documented dedicated Hetzner WireGuard gateway outside the cluster

The example overlay file for this direction is:

- `deploy/hetzner/profiles/prod-hybrid-onprem.example.tfvars`

That file only changes the Hetzner-managed side. It does not provision the HPE
servers.

## On-Prem Worker Join Model

After the Hetzner cluster is up:

1. prepare each HPE host with the normal worker prerequisites
2. install and start WireGuard on each host
3. verify tunnel reachability to the Hetzner gateway
4. join each host as a worker-only `k3s` agent using the WireGuard IP as node
   IP
5. label each node:

```bash
kubectl label node <node> skyforge.forwardnetworks.com/pool-class=onprem-lab --overwrite
kubectl label node <node> skyforge.forwardnetworks.com/provider=onprem --overwrite
kubectl label node <node> skyforge.forwardnetworks.com/site=colo-a --overwrite
```

Optional dedicated taint:

```bash
kubectl taint node <node> skyforge.forwardnetworks.com/pool-class=onprem-lab:NoSchedule
```

Only taint if the intended workloads already tolerate it.

## Workload Placement

Keep these cloud-side by default:

- `skyforge-server`
- `skyforge-server-worker`
- DB
- Redis
- Gitea
- observability
- ingress / Gateway API

Prefer the HPE workers for:

- clabernetes
- KubeVirt NOS workloads
- heavy lab jobs
- heavy reusable integrations that do not need to live at the public edge

Use Hetzner burst only as overflow after on-prem capacity is exhausted.

## Failure Model

If the HPE workers disappear:

- the cluster should stay healthy
- Skyforge should enter degraded hybrid mode
- capacity warnings should surface in Platform views
- eligible workloads should fall back to `burst` where allowed

This is a capacity degradation event, not a control-plane outage.

## Immediate Follow-On Work

1. add a dedicated Hetzner WireGuard gateway plan
2. create host-level WireGuard bootstrap steps for the HPE workers
3. validate pod/node/service traffic across the tunnel
4. attach the workers as `onprem-lab`
5. confirm placement and degraded-mode reporting in Skyforge
