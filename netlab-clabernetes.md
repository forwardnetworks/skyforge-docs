# Netlab → C9s (experimental)

Goal: use `netlab` to generate a Containerlab topology + node artifacts, and run the resulting topology on Kubernetes using the **clabernetes** controller (referred to as “c9s” in Skyforge).

References:
- Netlab: https://github.com/ipspace/netlab
- Clabernetes: https://containerlab.dev/manual/clabernetes/
- Clabverter (used by c9s): https://containerlab.dev/manual/clabernetes/install/#clabverter

This is intentionally “side-by-side” with the existing Netlab runner (EVE hosts) and Containerlab runner flows.

## High-level flow

1) **Template selection**
   - User selects a Netlab example folder (e.g. `netlab/EVPN/ebgp`) from blueprints/user repo.

2) **Sync template into workdir**
   - Copy selected template folder contents into a workdir root (same convention as the runner flow so `cd workdir && netlab up` works locally).

3) **Compile with netlab**
   - Run `netlab create` (and/or `netlab up --dry-run` if needed) to generate:
     - `clab.yml` (Containerlab topology)
     - `hosts.yml`, `node_files/`, `config/`, `group_vars/`, etc.
   - Skyforge runs `netlab create` in-cluster (using the netlab runtime image defaults at `/etc/netlab/defaults.yml`) and persists:
     - `clab.yml` + `node_files/` + `config/` (for clabernetes deploy)
     - `hosts.yml` + `netlab.snapshot.pickle` + vars (for post-deploy `netlab initial`)

## Runtime modes

`c9s/netlab` is cluster-native and generates artifacts in-cluster.

Netlab **(BYOS)** is a separate provider that runs on a user-supplied Netlab server over the Netlab API; it is intentionally not used by `c9s/netlab`.

### In-cluster runtime (required)

- Skyforge runs a Kubernetes Job (in the user namespace) that executes Netlab to generate artifacts.
- The runtime job writes:
  - a manifest ConfigMap (`c9s-<topology>-manifest`) containing `manifest.json`
  - per-node ConfigMaps containing `node_files/<node>/...` text files
  - startup config ConfigMap(s) containing generated `config/*.cfg` files
- Skyforge deploys the resulting containerlab definition via clabernetes, mounting the generated files via `filesFromConfigMap`.

### Configuration knobs

- Encore config (preferred): `ENCORE_CFG_SKYFORGE.Netlab`
  - `Mode`: `"k8s"`
  - `Image`: netlab runtime image (required for `c9s/netlab` generation and `netlab initial` apply)
  - `PullPolicy`: image pull policy for runtime jobs
- Helm values (recommended):
  - `skyforge.netlab.image`
  - `skyforge.netlab.pullPolicy`
- SR OS license injection (required when deploying `sros`):
  - `SKYFORGE_SROS_LICENSE_PATH`: absolute path to a `.license` file on the server pod/host.
  - or `SKYFORGE_SROS_LICENSE_B64`: base64-encoded license text.
  - Skyforge mounts this as `/.license` for SR OS nodes so vrnetlab can load it as `/tftpboot/license.txt`.

### Build the netlab runtime image

```bash
cd skyforge
./scripts/build-push-skyforge-netlab.sh --tag <tag>
```

4) **Deploy via c9s**
   - Skyforge creates a `Topology` custom resource embedding the Containerlab YAML (`spec.definition.containerlab`).
   - Skyforge mounts runtime-produced `node_files/` and `config/` artifacts into c9s launcher pods via `spec.deployment.filesFromConfigMap`.
   - The c9s controller uses **clabverter** internally to translate the containerlab definition into Kubernetes resources.

5) **Apply to Kubernetes**
   - Uses a per-user namespace (`ws-<userScopeSlug>`) to isolate resources.
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
  in the runtime image.
- Skyforge must remain cluster-native: no Docker socket mounts and no `docker exec` paths.
- SSH readiness gating:
  - Controlled by internal taskengine readiness windows derived from deployed device types.
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
   - For “ssh/https/snmp”, do we model a per-user placeholder credential set?

5) **Namespace lifecycle**
   - Create namespace on deployment create?
   - Delete namespace on deployment destroy (with finalizer/owner refs)?

## Implementation checklist (Skyforge)

- Server (encore/Go)
  - Deployment family/engine: `c9s` / `netlab`.
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
  - Ensure deployment creation uses `family` + `engine` (`c9s` / `netlab`) for this path.

- Helm / cluster
  - Ensure clabernetes controller installed and CRDs present in the cluster.
  - Decide where controller runs (namespace) and what RBAC is needed.

## Netlab plugin migration direction

The current `c9s/netlab` path remains a Skyforge wrapper around native netlab
artifacts (`netlab create` + `netlab initial`) and clabernetes CR apply.

The target architecture is to move more deployment semantics into a netlab
plugin contract over time, while keeping these invariants:
- Netlab remains source-of-truth for generated topology/config artifacts.
- Skyforge remains source-of-truth for user/deployment lifecycle, tenancy, and
  platform policy (leases, quotas, task orchestration, audit trail).
- No compatibility fallback contract in native mode once plugin contract
  versions are cut over.

Planned migration phases:
1. Keep current wrapper path as baseline (already deployed).
2. Define a strict plugin contract for K8s-native deployment metadata.
3. Shift wrapper-owned glue into plugin-emitted metadata and generated outputs.
4. Upstream where possible once contract stabilizes and drift is eliminated.

## Safety / guardrails

- Default-off behind a feature flag in `deploy/skyforge-values.yaml`.
- Hard cap: max pods/nodes per topology for MVP.
- Timeouts and clear error messages when CRDs/controller are missing.
- Capacity preflight is taint-aware and fit-aware:
  - excludes nodes with `NoSchedule`/`NoExecute` taints from candidate capacity
  - fails early when per-node placement cannot fit requested CPU/memory (even when aggregate free capacity looks sufficient)
