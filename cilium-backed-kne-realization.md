# Cilium-Backed KNE Realization

This note captures what a future Cilium-backed replacement for meshnet would
actually need to provide, and why that is a larger project than simply
enabling VXLAN in Cilium.

## Current Stack

- `netlab` defines topology intent and device configuration.
- `KNE` owns topology orchestration, node resource creation, and lifecycle.
- `meshnet` realizes arbitrary point-to-point lab links and extra interfaces.
- `Cilium` provides the underlying cluster dataplane, ingress, policy, and
  observability.

Today, Cilium is already part of the stack. The open problem is not generic
pod-to-pod networking; it is arbitrary lab-link realization.

## What A Cilium-Backed Replacement Would Need

Any replacement for meshnet that still keeps the `netlab -> KNE` workflow would
need to provide all of the following:

1. Topology intent ingestion
   - Read `KNE` and `netlab` topology intent directly.
   - Treat the topology graph as source of truth, not inferred pod state.

2. Per-node extra interface realization
   - Create deterministic extra interfaces inside lab pods or containers.
   - Preserve interface semantics such as `eth1`, `eth2`, `eth3`.

3. Point-to-point link realization
   - Realize one link per graph edge.
   - Support same-node and cross-node links.
   - Avoid collapsing lab edges into generic pod reachability.

4. Link isolation
   - Preserve topology isolation per logical link.
   - Ensure unrelated nodes do not share a segment unless the topology says so.

5. Reconciliation
   - Handle pod restart, node restart, late peer arrival, and delete cleanup.
   - Reconcile desired versus actual link state continuously.

6. Status and observability
   - Expose link readiness, pending peers, failures, and cleanup state.
   - Provide an equivalent to current `Topology.status.skipped` plus realized
     wire state.

7. Failure semantics
   - Recover cleanly from race conditions.
   - Avoid sticky failure bookkeeping that suppresses later success.

## What Cilium Already Provides

Cilium already gives us:

- cluster networking
- overlay or native routing dataplane
- identity and policy
- ingress and service routing
- observability via Hubble

Those are necessary, but they do not by themselves provide arbitrary lab-link
realization for `KNE`.

## What Cilium Does Not Provide Today

By itself, Cilium does not act as:

- a `KNE` topology controller
- a lab-link controller for arbitrary point-to-point edges
- an extra-interface realization layer for lab nodes
- a per-link status model for topology reconciliation

In other words, enabling VXLAN in Cilium is not equivalent to replacing
meshnet.

## Likely Shape Of A Replacement

A realistic Cilium-backed replacement would probably require:

- a controller that watches `KNE` topology resources
- a node-local agent or daemonset that programs link attachments
- a status CRD or equivalent realized-link state model
- explicit handling for interface naming and cleanup
- either `KNE` integration or a new `KNE` backend or plugin

That would be a new subsystem, not a chart toggle.

## Architectural Conclusion

If we want the smallest native change, use:

- `netlab`
- `KNE`
- `meshnet`
- switch `meshnet` mode from `grpc` to `vxlan`

If we want a true Cilium-backed replacement, we are talking about replacing the
meshnet realization layer while keeping `KNE` as the orchestration layer.

That is feasible in principle, but it is a design-and-build effort, not an
operational tweak.
