# Hybrid Worker Node Onboarding

This document defines the supported procedure for adding reclaimed colo or
Lab++ compute into a Skyforge cluster as `lab` or `onprem-lab` worker capacity.

The goal is simple:

- keep Skyforge control, portal, and core app workloads cloud-side
- attach optional on-prem worker nodes for lab execution
- use native Kubernetes placement and Cilium routing primitives
- make degraded behavior explicit when on-prem capacity disappears

## Intended Topology

Skyforge hybrid mode assumes:

- control-plane and core app workloads remain in the primary cloud footprint
- on-prem nodes join the same cluster as worker-only nodes
- lab workloads prefer `lab` or `onprem-lab` pools
- burst demand still lands on autoscaled cloud-side `burst` pools when allowed

This is not a split-brain model and not a second cluster.

## Networking Requirements

On-prem worker nodes must have stable L3 reachability to the existing cluster.

Required:

- routable node-to-node connectivity between cloud and on-prem worker nodes
- stable pod and service reachability through the cluster CNI
- MTU consistency across the transport path
- firewall rules that allow Kubernetes node traffic, Cilium dataplane traffic,
  and any overlay or VPN transport used for inter-site connectivity

Expected baseline:

- Cilium native routing
- site-to-site VPN or equivalent routed interconnect between cloud and colo
- no dependency on shared L2 adjacency

Do not attach on-prem workers until inter-node routing has been validated with
basic pod-to-pod and service-to-pod checks.

## Node Role and Scheduling Contract

Reclaimed colo nodes are worker-only.

They should not run:

- Kubernetes control-plane components
- Skyforge portal
- Skyforge API/server
- Skyforge worker unless explicitly intended

They are meant for:

- clabernetes lab workloads
- heavy integration workloads where placement policy allows it

Apply a clear pool-class label:

```bash
kubectl label node <node-name> skyforge.forwardnetworks.com/pool-class=onprem-lab --overwrite
```

Optional additional labels:

```bash
kubectl label node <node-name> skyforge.forwardnetworks.com/provider=onprem --overwrite
kubectl label node <node-name> skyforge.forwardnetworks.com/site=colo-a --overwrite
kubectl label node <node-name> skyforge.forwardnetworks.com/monthly-node-cost-cents=0 --overwrite
```

Recommended taint for dedicated lab capacity:

```bash
kubectl taint node <node-name> skyforge.forwardnetworks.com/pool-class=onprem-lab:NoSchedule
```

Only apply the taint if the relevant workloads already tolerate it.

## Onboarding Procedure

1. Prepare the node
- install the supported container runtime and Kubernetes prerequisites
- verify CPU virtualization and required kernel modules for intended workloads
- verify DNS and time sync

2. Join the node as a worker
- use the standard cluster join mechanism for the current deployment profile
- do not promote reclaimed colo nodes into control-plane roles

3. Apply placement labels
- set `skyforge.forwardnetworks.com/pool-class=onprem-lab`
- optionally apply provider, site, and cost labels

4. Verify cluster inventory

```bash
kubectl get nodes -L skyforge.forwardnetworks.com/pool-class,skyforge.forwardnetworks.com/provider,skyforge.forwardnetworks.com/site
```

5. Verify readiness

```bash
kubectl get nodes
kubectl top nodes
```

6. Verify Skyforge platform visibility
- admin capacity view should show the node pool as `onprem-lab`
- dashboard/platform warnings should clear once ready capacity is visible

## Reclaiming Lab++ or Existing Colo Compute

If compute is being reclaimed from Lab++ or another legacy environment:

1. remove it from the old scheduler or management contract first
2. ensure no legacy lab runtime is still mutating the node
3. wipe or reprovision the host to the Skyforge worker baseline
4. join it into the Skyforge cluster as worker-only capacity
5. label it as `onprem-lab`
6. verify that Skyforge capacity reporting now sees the pool

Do not try to dual-purpose the same host under two orchestration systems.

## Placement Expectations

Skyforge currently uses native Kubernetes placement intent and pool-class
reporting.

Expected behavior:

- server and worker prefer `app`
- lab workloads prefer `lab` / `onprem-lab`
- cloud `burst` pools remain the fallback for elastic capacity

A Hetzner burst variant fits this same contract: label those worker nodes as `burst` with `provider=hetzner`, terminate WireGuard on the local side, and make the Hetzner peers initiate the tunnel outbound.

If no `onprem-lab` nodes are ready:

- Skyforge should report hybrid-placement warnings
- new launches should still prefer any remaining valid `lab` or `burst` pools
- deployment detail should show degraded placement if the actual landing pool
  differs from preferred intent

## Verification Commands

Cluster-side:

```bash
kubectl get nodes -L skyforge.forwardnetworks.com/pool-class
kubectl describe node <node-name>
kubectl get pods -A -o wide
```

Placement-side:

```bash
kubectl get pod -n <lab-namespace> -o wide
kubectl get deploy -A | grep -E 'skyforge|clab|collector'
```

Skyforge-side:

- open `Dashboard`
- open `Platform > Capacity`
- inspect blended infrastructure, pool classes, and warnings
- open a c9s deployment detail page and inspect the `Placement` card

## Degraded-Mode Expectations

When `onprem-lab` capacity disappears, the expected operator response is:

1. confirm the node is actually unavailable
2. confirm whether workloads have fallen back to `lab` or `burst`
3. decide whether to restore on-prem capacity or keep running in cloud-only mode
4. update reservations or protected demo windows if capacity posture changed

This is an operational event, not a silent failure. The platform should expose
it in warnings and placement status.

## Non-Goals

This procedure does not:

- define a custom scheduler
- move control-plane workloads onto reclaimed colo nodes
- replace the current cloud baseline
- guarantee that all workloads should run on-prem

It only defines the supported way to add on-prem worker capacity into the same
Skyforge cluster model.
