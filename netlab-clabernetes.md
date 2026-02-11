# Netlab → C9s (experimental)

Goal: use `netlab` to generate a Containerlab topology + node artifacts, and run the resulting topology on Kubernetes using the **clabernetes** controller (referred to as “c9s” in Skyforge).

References:
- Netlab: https://github.com/ipspace/netlab
- Clabernetes: https://containerlab.dev/manual/clabernetes/
- Clabverter (used by c9s): https://containerlab.dev/manual/clabernetes/install/#clabverter

This is intentionally “side-by-side” with the existing Netlab runner (EVE hosts) and Containerlab runner flows.

## High-level flow

1) **Template selection**
   - User selects a Netlab example folder (e.g. `netlab/EVPN/ebgp`) from blueprints/workspace repo.

2) **Sync template into workdir**
   - Copy selected template folder contents into a workdir root (same convention as the runner flow so `cd workdir && netlab up` works locally).

3) **Compile with netlab**
   - Run `netlab create` (and/or `netlab up --dry-run` if needed) to generate:
     - `clab.yml` (Containerlab topology)
     - `hosts.yml`, `node_files/`, `group_vars/`, etc.
   - Skyforge runs `netlab create --plugin files` in-cluster and persists:
     - `clab.yml` + `node_files/` (for clabernetes deploy)
     - `hosts.yml` + `netlab.snapshot.pickle` + vars (for post-deploy `netlab initial`)

## Generator modes

`netlab-c9s` is cluster-native and generates artifacts in-cluster.

Netlab **(BYOS)** is a separate provider that runs on a user-supplied Netlab server over the Netlab API; it is intentionally not used by `netlab-c9s`.

### In-cluster generator (required)

- Skyforge runs a Kubernetes Job (in the workspace namespace) that executes Netlab to generate artifacts.
- The generator writes:
  - a manifest ConfigMap (`c9s-<topology>-manifest`) containing `manifest.json`
  - per-node ConfigMaps containing `node_files/<node>/...` text files
- Skyforge deploys the resulting containerlab definition via clabernetes, mounting the generated files via `filesFromConfigMap`.

### Configuration knobs

- Encore config (preferred): `ENCORE_CFG_SKYFORGE.NetlabGenerator`
  - `C9sGeneratorMode`: `"k8s"`
  - `GeneratorImage`: netlab generator image (required for `netlab-c9s`)
  - `ApplierImage`: netlab applier image (required for `netlab initial` apply)
- Helm values (recommended):
  - `skyforge.netlabC9s.generatorImage`
  - `skyforge.netlabC9s.generatorPullPolicy`
  - `skyforge.netlabC9s.applierImage`
  - `skyforge.netlabC9s.applierPullPolicy`

#### Resource policy defaults (k8s)

- Skyforge injects per-node Kubernetes **requests** for clabernetes topologies by default.
- Limits are disabled by default (`SKYFORGE_CLABERNETES_ENABLE_LIMITS=false`) to preserve containerlab-like burst behavior.
- If a node image has no known profile, fallback behavior is controlled by `SKYFORGE_CLABERNETES_RESOURCE_FALLBACK`:
  - `conservative` (default): apply fallback requests
  - `none`: skip unresolved nodes
  - `fail`: reject deployment

### Build the generator image

```bash
cd netlab/generator
docker buildx build --platform linux/amd64 \
  -t ghcr.io/forwardnetworks/skyforge-netlab-generator:<tag> \
  --push .
```

### Build the applier image

```bash
cd netlab/applier
docker buildx build --platform linux/amd64 \
  -t ghcr.io/forwardnetworks/skyforge-netlab-applier:<tag> \
  --push .
```

4) **Deploy via c9s**
   - Skyforge creates a `Topology` custom resource embedding the Containerlab YAML (`spec.definition.containerlab`).
   - Skyforge also creates per-node ConfigMaps for `node_files/` and mounts them into c9s launcher pods via `spec.deployment.filesFromConfigMap`.
   - The c9s controller uses **clabverter** internally to translate the containerlab definition into Kubernetes resources.

5) **Apply to Kubernetes**
   - Uses a per-workspace namespace (`ws-<workspaceSlug>`) to isolate resources.
   - Applies the `Topology` CR; waits for `status.topologyReady=true`.

6) **Status + logs**
   - Provide a deployment “info” panel backed by Kubernetes queries:
     - CR status conditions
     - pod states
     - controller events

7) **Apply post-deploy config (`netlab initial`)**
   - Skyforge runs a Kubernetes Job that:
     - reconstructs `node_files/` locally from per-node ConfigMaps
     - patches netlab inventory/snapshot to use k8s Service DNS names
     - waits for an SSH banner on all NOS nodes (vrnetlab pods can be "Running" long before SSH is ready)
     - runs `netlab initial` (Ansible playbooks)

8) **Export to Forward (devices/IPs)**
   - Extract the device list + reachable management endpoints.
   - In k8s, the “mgmt” address might be:
     - a Service per node (stable name, cluster IP), or
     - Pod IPs (not stable), or
     - a LoadBalancer/NodePort (unlikely in this environment)
   - For the MVP, define a consistent “connection” strategy and document it (e.g. `ssh <node>.<ns>.svc` via a Service, or a bastion model).

## Notes

- `netlab initial` uses netlab’s Ansible task library (`netsim/ansible/...`) and requires
  the corresponding Ansible network collections (Junos/NXOS/IOS/EOS/etc.) to be present
  in the applier image.
- Skyforge must remain cluster-native: no Docker socket mounts and no `docker exec` paths.
- SSH readiness gating:
  - Controlled by `SKYFORGE_NETLAB_INITIAL_SSH_READY_SECONDS` (defaults to `SKYFORGE_FORWARD_SSH_READY_SECONDS`, default 900s).
  - Uses an SSH banner check (reads `SSH-`), not just a TCP connect, to reduce false positives.

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
  - Deployment type: `netlab-c9s`.
  - Runner flow:
    - sync template → runner workdir
    - `netlab create` → `netlab clab-tarball`
    - create per-node ConfigMaps for `node_files/`
    - create c9s `Topology` CR embedding `clab.yml`
    - wait for readiness
  - Destroy flow:
    - delete `Topology` CR
    - delete generated ConfigMaps

- Portal
  - Add `netlab-c9s` to deployment type picker.

- Helm / cluster
  - Ensure clabernetes controller installed and CRDs present in the cluster.
  - Decide where controller runs (namespace) and what RBAC is needed.

## Notes on “adding c9s to netlab”

We likely do **not** need to modify upstream netlab to add a native “c9s” provider to get an MVP:
- Netlab already emits Containerlab topology (`clab.yml`) via the `clab` provider.
- Clabernetes consumes containerlab topologies via Kubernetes CRDs/controllers.
- The simplest integration is therefore a **wrapper**:
  - `netlab create` → `clab.yml` → clabernetes CR apply

If we later want a “first-class” experience in netlab itself (e.g., `netlab up --provider c9s`), that would be an upstream effort and should be treated as Phase 3+ after the Skyforge wrapper works reliably.

## Safety / guardrails

- Default-off behind a feature flag in `deploy/skyforge-values.yaml`.
- Hard cap: max pods/nodes per topology for MVP.
- Timeouts and clear error messages when CRDs/controller are missing.
