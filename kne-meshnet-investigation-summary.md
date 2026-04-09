# KNE Meshnet Investigation Summary

This document records the April 9, 2026 investigation into the native KNE or
meshnet skipped-link failure that can leave quick-deploy topologies stuck in
`Init:0/1`.

## Confirmed Failure

The strongest confirmed failure remains the live quick-deploy namespace
`user-cr-71afa445`.

Confirmed signature:

- topology namespace exists and most pods are created
- pods `h1` and `l1` remained in `Init:0/1`
- init logs repeated:
  - `h1`: `Connected 1 interfaces out of 2`
  - `l1`: `Connected 3 interfaces out of 4`
- `Topology.status.skipped` contained `l1 -> h1 (link_id=8)`
- `GWireKObj` had no `link_id=8`
- meshnet logs contained `Pod h1, skipping peer pod l1 for link UID 8`

Evidence bundle:

- [SUMMARY.md](/home/captainpacket/src/skyforge/artifacts/kne-meshnet-evidence/user-cr-71afa445-20260409T143736Z/SUMMARY.md)
- [user-cr-71afa445-20260409T143736Z.tar.gz](/home/captainpacket/src/skyforge/artifacts/kne-meshnet-evidence/user-cr-71afa445-20260409T143736Z.tar.gz)

## Environment

Verified environment capture with running image IDs:

- [SUMMARY.md](/home/captainpacket/src/skyforge/artifacts/kne-meshnet-investigation/20260409T164200Z-env-check/env/SUMMARY.md)

Key values:

- Kubernetes server: `v1.35.3+k3s1`
- meshnet spec image: `us-west1-docker.pkg.dev/kne-external/kne/networkop/meshnet:v0.3.2`
- meshnet running digest: `sha256:bb752df44f956088a484d3b2f0499e9302a1d555b5e69263a125ba5f0a9d9e50`
- CEOS operator manager image: `ghcr.io/aristanetworks/arista-ceoslab-operator:v2.1.2`
- CEOS operator manager digest: `sha256:2ce5be0bc7790dc7d5f81fc30d9224d81f8129495f1410f00d040c72d99cbf51`

## Ownership

The current evidence points to native meshnet or meshnet-backed wire
reconciliation, not to Skyforge orchestration.

Relevant upstream source paths:

- `/tmp/meshnet-cni-src/plugin/grpcwires-plugin.go`
  - cross-node GRPC wire setup
  - low-priority side waits on `IsSkipped(...)` and may leave wire creation to
    the higher-priority peer
- `/tmp/meshnet-cni-src/daemon/meshnet/handler.go`
  - writes `Topology.status.skipped` in `Skip(...)`
  - reads skip state in `IsSkipped(...)`
- `/tmp/meshnet-cni-src/daemon/grpcwire/gwire_recon.go`
  - persists and reconstructs `GWireKObj.status.grpcWireItems`

Important nuance:

- `Topology.status.skipped` is sticky bookkeeping
- it is not a self-clearing failure bit
- successful runs can still show historical skip entries

That means the actionable failure signature requires all of the following at the
same time:

- init still blocked
- repeated `Connected N interfaces out of M`
- matching skipped entry
- matching missing `GWireKObj` link
- matching meshnet skip log

## Minimization Ladder

Direct path used for all reduced cases:

- `netlab create -> kne_cli create`

Results:

1. Full EVPN baseline
   - [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/EVPN/ebgp/topology.yml)
   - corrected harness direct runs: 3 passes

2. Single edge
   - [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/_smoke/kne-meshnet-linux-ceos-link/topology.yml)
   - corrected harness direct runs: 10 passes

3. Leaf fanout
   - [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/_smoke/kne-meshnet-leaf-fanout/topology.yml)
   - corrected harness direct runs: 10 passes

4. Dual leaf shared spines
   - [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/_smoke/kne-meshnet-dual-leaf-shared-spines/topology.yml)
   - corrected harness direct runs: 10 passes
   - a prior pre-correction probe produced one non-matching timeout caused by
     CEOS startup-probe delay, not by the target skipped-link signature
   - summary artifact:
     - [SUMMARY.md](/home/captainpacket/src/skyforge/artifacts/kne-meshnet-investigation/20260409T161500Z-dual-leaf-v2/SUMMARY.md)

## What We Ruled Out

- This is not the earlier Skyforge manifest-contract bug.
- This is not explained by the reduced direct-path topologies tested so far.
- `status.skipped` by itself is not sufficient evidence of failure.
- the first dual-leaf timeout was not the target failure; it was CEOS
  `wfw -t 5` startup-probe slowness after transient skip bookkeeping.

## Decision

Current classification: `insufficient` for a reduced deterministic reproducer.

What is established:

1. the hard failure is real
2. the confirmed failure boundary is below Skyforge
3. reduced direct-path `_smoke` cases tested so far do not reproduce it

What is not established yet:

1. the smallest direct-path deterministic reproducer
2. a fork-ready meshnet patch target with regression coverage

## Next Step

Move the investigation back up to the full quick-deploy EVPN shape using the
corrected matcher and evidence collector.

That means:

1. create fresh full-shape runs
2. preserve the first matching failure
3. compare direct `kne_cli create` versus quick-deploy orchestration for the
   same topology shape
4. only if the failure remains below Skyforge after that comparison, prepare an
   upstream-ready or fork-ready packet against meshnet
