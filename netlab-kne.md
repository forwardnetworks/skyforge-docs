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
  - canonical node metadata (`deviceKey`, `forwardType`) in the manifest contract

## Runtime modes

`c9s/netlab` is cluster-native and generates artifacts in-cluster.

Netlab **(BYOS)** is a separate provider that runs on a user-supplied Netlab server over the Netlab API; it is intentionally not used by `c9s/netlab`.

### In-cluster runtime (required)

- Skyforge runs one Kubernetes runtime job for bring-up (`netlab.py up`) in the user namespace.
- `netlab.py up` owns the full runtime path:
  - `netlab create` from the provided topology bundle
  - manifest generation and manifest schema validation
  - writing manifest + node/shared/startup/license/output ConfigMaps
  - best-effort per-topology image warm-up (DaemonSet pre-pull in topology namespace)
  - creating/updating the clabernetes `Topology` CR
  - waiting for topology readiness
  - running netlab apply (`netlab initial` and device-specific semantics)
  - defaulting `netlab initial` to `--fast` (Ansible free strategy) unless explicitly overridden
- Skyforge runs one Kubernetes runtime job for teardown (`netlab.py down`):
  - deletes the clabernetes `Topology` CR
  - deletes c9s runtime ConfigMaps labeled for that topology
  - then taskengine performs post-destroy DB/orphan cleanup

### Configuration knobs

- Encore config (preferred): `ENCORE_CFG_SKYFORGE.Netlab`
  - `Mode`: `"k8s"`
  - `Image`: netlab runtime image (required for `c9s/netlab` generation and deploy/apply phases)
  - `PullPolicy`: image pull policy for runtime jobs
- Runtime env toggles (optional, consumed by `netlab.py up`):
  - `SKYFORGE_KNE_PREPULL_ENABLED` (default `true`)
  - `SKYFORGE_KNE_PREPULL_MAX_IMAGES` (default `8`)
  - `SKYFORGE_KNE_PREPULL_TIMEOUT_SECONDS` (default `180` per image)
- Helm values (recommended):
  - `skyforge.netlab.image`
  - `skyforge.netlab.pullPolicy`
  - `skyforge.netlab.runtimePrepull.enabled` (cluster-level runtime image warm cache)
  - runtime-prepull DaemonSets are worker-only and must not schedule on
    tainted control-plane nodes
- SR OS license injection (required when deploying `sros`):
  - `SKYFORGE_SROS_LICENSE_PATH`: absolute path to a `.license` file on the server pod/host.
  - or `SKYFORGE_SROS_LICENSE_B64`: base64-encoded license text.
  - Skyforge mounts this as `/.license` for SR OS nodes so vrnetlab can load it as `/tftpboot/license.txt`.

### Build the netlab runtime image

```bash
cd skyforge
./scripts/build-push-skyforge-netlab.sh --tag <tag>
```

### Build the Linux host image (SSH + periodic activity)

Linux endpoints use a dedicated image (`skyforge-linux-host`) with `sshd` and a
deterministic background activity loop (once per minute by default, configurable
via `NETLAB_HOST_ACTIVITY_INTERVAL`).

```bash
cd skyforge
./scripts/build-push-skyforge-linux-host.sh --tag <tag>
```

4) **Deploy via c9s**
   - Netlab runtime `up` creates a `Topology` custom resource embedding the Containerlab YAML (`spec.definition.containerlab`).
   - Netlab runtime `up` mounts runtime-produced `node_files/` and `config/` artifacts into c9s launcher pods via `spec.deployment.filesFromConfigMap`.
   - For `deployPolicy.schedulingMode=spread`, Skyforge injects both pod anti-affinity preference and pod `topologySpreadConstraints` on hostname to improve multi-node distribution.
   - The c9s controller uses **clabverter** internally to translate the containerlab definition into Kubernetes resources.

5) **Apply to Kubernetes**
   - Uses a per-user namespace (`ws-<userScopeSlug>`) to isolate resources.
   - Netlab runtime `up` applies the `Topology` CR and waits for `status.topologyReady=true`.
   - Skyforge now marks KNE runtime namespaces as ephemeral runtime namespaces with:
     - label `skyforge.forwardnetworks.com/ephemeral-runtime=true`
     - purpose label `skyforge.forwardnetworks.com/runtime-purpose=<kne-runtime|kne-topology>`
     - owner annotations for deployment, topology, and user-scope identity
     - expiry annotation `skyforge.forwardnetworks.com/expires-at`
   - Default retention for these ephemeral namespaces is `24h` unless cleanup happens earlier as part of normal destroy flow.

6) **Status + logs**
   - Provide a deployment “info” panel backed by Kubernetes queries:
     - CR status conditions
     - pod states
     - controller events
   - Skyforge now also exposes a per-node authenticated browser/API proxy at:
     - `/api/users/:id/deployments/:deploymentID/browser/:node/*rest`
   - Default upstream target is `https://service-<node>.<runtime-namespace>.svc.cluster.local:443`.
   - Operators can override `scheme` and `port` via query params for non-default device APIs.
   - This path is solid for API access and best-effort for GUI access; some appliance GUIs with absolute-root redirects/assets may still need a dedicated integration route.

7) **Run netlab apply phase**
   - Netlab runtime `up`:
     - reconstructs `node_files/` locally from per-node ConfigMaps
     - runs netlab runtime apply (`netlab initial` and netlab-native config modules)

### KubeVirt multi-node contract

- For KubeVirt-backed NOSes, `eth0` remains reserved for management. Generated
  data-plane links must start at `eth1`; otherwise KNE meshnet peer resolution
  and Multus attachment ordering break for VM-backed nodes.
- The `skyforge-netlab-runtime` service account must be allowed to manage
  `network-attachment-definitions` in the topology namespace because KNE fabric
  reconciliation creates and updates those NADs during KubeVirt bring-up.
- KubeVirt fabric reconciliation should preserve logical node topology aliases
  for non-VM peers and must not add a second meshnet topology against the
  `virt-launcher-*` pod when the VM already receives data links via Multus.

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
- Skyforge does not implement per-device initial-policy or SSH-auth gating for c9s/netlab apply;
  those checks are owned by netlab runtime behavior.

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
   - Skyforge now performs two cleanup paths:
     - normal destroy cleanup for active deployments
     - periodic orphan cleanup for expired or inactive ephemeral runtime namespaces, including legacy `smoke-*`, `rt-*`, and `user-*` namespaces
   - Stuck `Terminating` namespaces that are explicitly labeled `skyforge.forwardnetworks.com/ephemeral-runtime=true` now have a second-stage force-finalize path after the grace window passes.

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

The current `c9s/netlab` path keeps Skyforge as orchestrator while netlab
runtime owns native netlab artifacts (`netlab create` + `netlab initial`) and
clabernetes CR apply sequencing.

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
  - applies policy headroom reserves before fit checks:
    - `capacityReserveCpuPercent` (default `10`)
    - `capacityReserveMemoryPercent` (default `10`)
