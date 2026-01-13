# Netlab → Clabernetes (experimental) TODO

Goal: add an experimental deployment path that uses `netlab` to generate a topology + artifacts, and runs the resulting Containerlab topology on Kubernetes using the **clabernetes** controller.

This is intentionally “side-by-side” with the existing Netlab runner (EVE hosts) and Containerlab runner flows.

## High-level flow (proposed)

1) **Template selection**
   - User selects a Netlab example folder (e.g. `netlab/EVPN/ebgp`) from blueprints/workspace repo.

2) **Sync template into workdir**
   - Copy selected template folder contents into a workdir root (same convention as the runner flow so `cd workdir && netlab up` works locally).

3) **Compile with netlab**
   - Run `netlab create` (and/or `netlab up --dry-run` if needed) to generate:
     - `clab.yml` (Containerlab topology)
     - `hosts.yml`, `node_files/`, `group_vars/`, etc.
   - For the first iteration, focus on generating `clab.yml` and any artifacts needed for “export device list”.

4) **Convert → clabernetes**
   - Option A (preferred if supported): create a `Topology` custom resource that embeds the Containerlab topology (`clab.yml`) directly.
   - Option B (if required): run **clabverter** to convert `clab.yml` into Kubernetes resources/CRs consumable by clabernetes.

5) **Apply to Kubernetes**
   - Use a per-workspace namespace (e.g. `sf-ws-<slug>` or `sf-ws-<id>`) to isolate resources.
   - Apply CRs/resources; wait for controller reconciliation.

6) **Status + logs**
   - Provide a deployment “info” panel backed by Kubernetes queries:
     - CR status conditions
     - pod states
     - controller events

7) **Export to Forward (devices/IPs)**
   - Extract the device list + reachable management endpoints.
   - In k8s, the “mgmt” address might be:
     - a Service per node (stable name, cluster IP), or
     - Pod IPs (not stable), or
     - a LoadBalancer/NodePort (unlikely in this environment)
   - For the MVP, define a consistent “connection” strategy and document it (e.g. `ssh <node>.<ns>.svc` via a Service, or a bastion model).

## MVP scope (recommended)

Start with “works end-to-end” for topologies that use only images that are already cluster-accessible:

- Linux nodes (`kind: linux`) + public images (alpine/frr) only
- No vendor images (ceos/junos) in the first iteration
- No `netlab initial` / SSH readiness / device config push (avoid the hardest part initially)
- Still generate and upload the “devices + mgmt endpoints” list so Forward upload can be validated

## Phase 2 / Phase 3

- Phase 2: support vendor images where licensing allows (private registry / on-cluster preloading).
- Phase 3: support Netlab “initial configuration” semantics:
  - Prefer startup-config/configmaps mounted into containers over SSH-driven config
  - Any SSH-based approach should be optional and best-effort

## Open questions

1) **CRD API shape**
   - What exact CRD does our clabernetes controller expect?
   - Can it embed a raw containerlab YAML, or does it require a transformed schema?

2) **Mgmt connectivity model**
   - What hostname/IP should users and integrations use?
   - Do we want per-node Services? A single jump service? Something else?

3) **Artifact persistence**
   - Do we store `clab.yml` + generated artifacts in S3 (like other runners), or keep them ephemeral?

4) **Forward device upload**
   - What stable management endpoint do we record for each node?
   - For “ssh/https/snmp”, do we model a per-workspace placeholder credential set?

5) **Namespace lifecycle**
   - Create namespace on deployment create?
   - Delete namespace on deployment destroy (with finalizer/owner refs)?

## Implementation checklist (Skyforge)

- Server (encore/Go)
  - Add new deployment type `netlab-clabernetes` (experimental).
  - Add runner for:
    - sync template → workdir
    - run `netlab create`
    - produce/apply clabernetes CRs
    - poll status / stream logs (best-effort)
  - Add destroy path that cleans up k8s resources and handles stuck finalizers.

- Portal
  - Add new deployment type option + “experimental” badge.
  - Reuse the existing run output streaming + dashboard SSE for status.

- Helm / cluster
  - Ensure clabernetes controller installed and CRDs present in the cluster.
  - Decide where controller runs (namespace) and what RBAC is needed.

## Safety / guardrails

- Default-off behind a feature flag in `deploy/skyforge-values.yaml`.
- Hard cap: max pods/nodes per topology for MVP.
- Timeouts and clear error messages when CRDs/controller are missing.

