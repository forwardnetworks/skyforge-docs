# KNE Meshnet Skipped-Link Runbook

This runbook documents the native KNE or meshnet failure mode where a topology reaches pod creation, but one or more links never reconcile and the pod `init-wait` container blocks forever.

## Failure Signature

A native KNE skipped-link failure has all of these characteristics:

1. The topology namespace exists and most pods are created.
2. One or more pods remain in `Init:0/1`.
3. The init container logs repeat `Connected N interfaces out of M`.
4. The `Topology` CR status contains `status.skipped` entries for the missing peer link.
5. The namespace `GWireKObj` state has no matching `link_id` for the skipped peer link.
6. Meshnet logs contain lines such as `Pod <a>, skipping peer pod <b> for link UID <n>`.

Important nuance: `status.skipped` is sticky bookkeeping, not a self-clearing failure bit.

In upstream meshnet source:

- `daemon/meshnet/handler.go` writes `status.skipped` in `Skip(...)`
- `daemon/meshnet/handler.go` consults it in `IsSkipped(...)`
- `plugin/grpcwires-plugin.go` uses `IsSkipped(...)` to decide which side creates a cross-node wire
- `daemon/grpcwire/gwire_recon.go` owns `GWireKObj.status.grpcWireItems`

There is no corresponding "clear skipped when the wire finally exists" path during normal success handling. That means `status.skipped` can remain after the link eventually converges.

Because of that, `status.skipped` alone is not enough to declare failure. The actionable signature is the full combination above: stuck init, repeated interface-count wait, missing `GWireKObj` link, and matching meshnet skip logs for the same `link_id`.

When that full signature is present, Skyforge has already handed the topology to KNE correctly. The failure is in native KNE or meshnet link reconciliation, not in Skyforge deployment state or manifest handling.

Current Skyforge behavior:

- netlab-KNE quick-deploy runs now fail this signature explicitly as
  `meshnet-skipped-link` instead of waiting for a generic deploy timeout
- the task event payload includes the topology namespace, skipped-link sample,
  and a ready-to-run evidence collector command
- Skyforge does not try to repair this by deleting host `koko*` links or
  patching the live meshnet DaemonSet. The durable fix belongs in the pinned
  meshnet image selected through Helm values.

## Observed Live Example

Observed on April 9, 2026 in namespace `user-cr-71afa445` from quick deploy template [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/EVPN/ebgp/topology.yml).

Relevant facts from the live namespace:

- Stuck pods:
  - `h1`: `Connected 1 interfaces out of 2`
  - `l1`: `Connected 3 interfaces out of 4`
- `Topology.status.skipped` contains:
  - `l1 -> h1` on `link_id=8`
- Meshnet logs contain:
  - `Pod h1, skipping peer pod l1 for link UID 8`
- `GWireKObj` has no `link_id: 8` anywhere in the namespace.

That means the missing `h1 <-> l1` wire was skipped during meshnet reconciliation and never appeared in the final wire-state object set.

## Collect Evidence

Use the built-in collector script:

```bash
cd /home/captainpacket/src/skyforge
./scripts/collect-kne-meshnet-evidence.sh \
  --namespace user-cr-71afa445 \
  --topology-file components/blueprints/netlab/EVPN/ebgp/topology.yml
```

The script writes:

- namespace resources
- pod descriptions
- init/app container logs
- `Topology` CR dumps
- `GWireKObj` dumps
- meshnet controller logs
- `SUMMARY.md`
- a tarball for sharing upstream

Default output root:

```text
artifacts/kne-meshnet-evidence/<namespace>-<timestamp>
```

## How To Read The Bundle

Start with `SUMMARY.md`.

Then confirm the controller failure in this order:

1. `pods-wide.txt`
   - find pods in `Init:0/1`
2. `pods/<pod>.init-*.log`
   - confirm interface count stalls
3. `topology.json`
   - confirm `status.skipped` for the same peer link
4. `gwirekobj.json`
   - confirm the skipped `link_id` is absent from the wire state
5. `meshnet/*.log`
   - confirm `skipping peer pod` for the same `link UID`

If `status.skipped` is present but the pods are already `Running` and `GWireKObj` contains the link, treat that as transient bookkeeping, not as the target failure.

## IaC Pinning

Meshnet image selection is chart-driven.

Use:

- `skyforge.kne.meshnet.image`
- `skyforge.kne.meshnet.imagePullPolicy`

Do not patch the live meshnet DaemonSet image directly without back-porting the
same pin into Helm values.

## Boundary

Do not fix this in Skyforge with:

- deployment retries
- pod restart loops
- namespace guessing
- same-node placement tricks
- manual post-processing of KNE wire state

Those are workflow workarounds, not ownership-correct fixes.

## Clean Options

1. Preferred: fix native KNE or meshnet reconciliation
   - build the smallest deterministic reproducer
   - open an upstream issue or PR with the collected evidence
2. If upstream is too slow and this is product-blocking: carry a minimal fork
   - constrain it to missed-link reconciliation only
   - require a deterministic regression case before shipping
3. Rejected: workflow hacks in Skyforge
   - they hide the controller defect and blur the component contract

## Ownership Map

The current evidence points to meshnet or meshnet-backed wire reconciliation, not to Skyforge:

- `plugin/grpcwires-plugin.go`
  - cross-node GRPC wire creation
  - low-priority side waits on `IsSkipped(...)` and may exit if the higher-priority peer is expected to create the wire
- `daemon/meshnet/handler.go`
  - writes `Topology.status.skipped`
  - answers `IsSkipped(...)`
- `daemon/grpcwire/gwire_recon.go`
  - persists and reconstructs `GWireKObj.status.grpcWireItems`

That ownership split matters. Skyforge should not try to "repair" this by retrying deployments, restarting pods, or mutating topology data after KNE accepts it.

## Candidate Minimization Path

The current observed failing deployment is the `EVPN/ebgp` quick deploy template. The smallest *observed failing subgraph* inside it is:

- `H1` (`linux`)
- `L1` (`ceos`)
- link `H1-L1`

That is not yet a proven deterministic reproducer by itself, but it is the right first minimization target.

Candidate blueprint:

- [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/_smoke/kne-meshnet-linux-ceos-link/topology.yml)

## Minimization Results

Observed on April 9, 2026:

1. Single-edge case: [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/_smoke/kne-meshnet-linux-ceos-link/topology.yml)
   - `netlab create -> kne_cli create` passed 10 consecutive times.
   - The `h1 <-> l1` cross-node link by itself is not sufficient to reproduce the failure.

2. Leaf fanout case: [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/_smoke/kne-meshnet-leaf-fanout/topology.yml)
   - Earlier probing showed transient `Topology.status.skipped` entries during boot.
   - After the stricter matcher was added, `netlab create -> kne_cli create` passed 10 consecutive times.
   - This topology can surface transient skip bookkeeping, but it did not reproduce the full stuck-init plus missing-`GWireKObj` signature.

3. Dual-leaf shared-spine case: [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/_smoke/kne-meshnet-dual-leaf-shared-spines/topology.yml)
   - This is the next minimization step that preserves shared-spine concurrency.
   - A prior probe produced one non-matching timeout caused by CEOS startup-probe delays, not by the target skipped-link signature.
   - After the stricter matcher was added, this case passed 10 consecutive direct-path attempts.
   - The reduced shared-spine case is therefore not the smallest confirmed reproducer.

4. Full EVPN baseline: [topology.yml](/home/captainpacket/src/skyforge/components/blueprints/netlab/EVPN/ebgp/topology.yml)
   - Direct `netlab create -> kne_cli create` runs passed 3 consecutive times in the corrected harness.
   - The strongest confirmed matching failure is still the live quick-deploy namespace `user-cr-71afa445`.

## Current Conclusion

As of April 9, 2026:

- `single-edge-linux-ceos`: 10 direct-path passes
- `leaf-fanout`: 10 direct-path passes after matcher correction
- `dual-leaf-shared-spines`: 10 direct-path passes after matcher correction
- `EVPN/ebgp` direct baseline: 3 passes
- strongest confirmed matching failure: quick deploy namespace `user-cr-71afa445`

That means the smallest confirmed reproducer is still not a reduced `_smoke` case. The current best conclusion is:

1. the hard failure is real
2. it belongs to native meshnet or KNE wire reconciliation, not Skyforge
3. the reduced direct-path cases tested so far are not sufficient to reproduce it deterministically
4. the next investigation step should move back up to the full quick-deploy EVPN shape using the corrected matcher and the evidence collector
