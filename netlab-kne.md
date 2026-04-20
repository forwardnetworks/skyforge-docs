# Netlab → KNE (experimental)

Goal: use `netlab` to generate a KNE topology + node artifacts, and run the resulting topology on Kubernetes using the **kne** controller (referred to as “kne” in Skyforge).

Contract note:
- Skyforge KNE uses top-level `provider: kne`.
- Nested node/image metadata may still use upstream `clab` subtrees where netlab models container attributes that way.
- Skyforge does not translate `provider: kne` into `provider: clab` at runtime.

References:
- Netlab: https://github.com/ipspace/netlab
- KNE: https://kne.dev/manual/kne/
- Clabverter (used by kne): https://kne.dev/manual/kne/install/#clabverter

This is intentionally “side-by-side” with the existing Netlab runner (EVE hosts) and KNE runner flows.

## High-level flow

1) **Template selection**
   - User selects a Netlab example folder (e.g. `netlab/EVPN/ebgp`) from blueprints/user repo.

2) **Sync template into workdir**
   - Copy selected template folder contents into a workdir root (same convention as the runner flow so `cd workdir && netlab up` works locally).

3) **Compile with netlab**
   - Run `netlab create` (and/or `netlab up --dry-run` if needed) to generate:
     - `clab.yml` (KNE topology)
     - `hosts.yml`, `node_files/`, `config/`, `group_vars/`, etc.
- Skyforge runs `netlab create` in-cluster (using the netlab runtime image defaults at `/etc/netlab/defaults.yml`) and persists:
  - `clab.yml` + `node_files/` + `config/` (for kne deploy)
  - `hosts.yml` + `netlab.snapshot.pickle` + vars (for post-deploy `netlab initial`)
  - canonical node metadata (`deviceKey`, `forwardType`) in the manifest contract
  - provider bootstrap overrides from `/etc/netlab/templates/<device>` when present (for example EOS bootstrap behavior)
    so SNMP community comes from `snmp_config/<device>.j2` instead of provider bootstrap startup text
  - `groups.all.config: [snmp_config]` in runtime defaults enables the shared SNMP configlet path by default

## Runtime modes

`kne/netlab` is cluster-native and generates artifacts in-cluster.

Netlab **(BYOS)** is a separate provider that runs on a user-supplied Netlab server over the Netlab API; it is intentionally not used by `kne/netlab`.

### In-cluster runtime (required)

- Skyforge runs one Kubernetes runtime job for bring-up (`netlab.py up`) in the user namespace.
- `netlab.py up` owns the full runtime path:
  - `netlab create` from the provided topology bundle
  - manifest generation and manifest schema validation
  - writing manifest + node/shared/startup/license/output ConfigMaps
  - best-effort per-topology image warm-up (DaemonSet pre-pull in topology namespace)
  - creating/updating the kne `Topology` CR
  - waiting for topology readiness
  - running netlab apply (`netlab initial` and device-specific semantics)
  - defaulting `netlab initial` to `--fast` (Ansible free strategy) unless explicitly overridden
- For deployment-scoped KNE runs, the native netlab KNE provider must honor
  `NETLAB_KNE_TOPOLOGY_NAME` as the actual topology owner/namespace identity.
  This keeps duplicate blueprint launches isolated from each other instead of
  reusing the blueprint's static topology name.
- Skyforge runs one Kubernetes runtime job for teardown (`netlab.py down`):
  - deletes the kne `Topology` CR
  - deletes kne runtime ConfigMaps labeled for that topology
  - then taskengine performs post-destroy DB/orphan cleanup

### Configuration knobs

- Encore config (preferred): `ENCORE_CFG_SKYFORGE.Netlab`
  - `Mode`: `"k8s"`
  - `Image`: netlab runtime image (required for `kne/netlab` generation and deploy/apply phases)
  - `PullPolicy`: image pull policy for runtime jobs
- Helm-rendered typed Encore config is the deployment-time source of truth for this runtime image contract:
  - `skyforge.netlab.image`
  - `skyforge.netlab.pullPolicy`
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

For KNE `HOST` pods specifically, the container command is overridden to
`sleep ...`, so the image entrypoint is bypassed. SSH and the background
activity loop therefore have to be bootstrapped from the generated initial
config template, not assumed to come from the image entrypoint alone.

```bash
cd skyforge
./scripts/build-push-skyforge-linux-host.sh --tag <tag>
```

4) **Deploy via kne**
   - Netlab runtime `up` generates the KNE runtime manifest and KNE CLI topology input from the netlab output bundle.
   - Skyforge hands that runtime-owned topology to `kne_cli create`; Skyforge does not post a custom `Topology.spec.deployment` contract or patch the stock KNE CRD.
   - The KNE runtime then creates the topology resources and meshnet wiring from that CLI input.

5) **Apply to Kubernetes**
   - Uses a per-user namespace (`ws-<userScopeSlug>`) to isolate resources.
   - `kne_cli create` is the bounded creation phase; Skyforge then waits on pod/runtime readiness rather than treating CR status alone as final success.
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
     - refreshes runtime inventory through the upstream KNE provider `post_start_lab` hook after `kne create`
       so `hosts.yml` and `netlab.snapshot.pickle` point at the real KNE service endpoints
     - derives per-node apply behavior from the generated netlab device catalog:
       - `startup-config` devices stay on topology startup-config
       - designer inline startup config is materialized before save into deterministic `.designer-startup/<template-base>/<node>.cfg` files, then consumed through the same topology startup-config path
       - `sh`/`cp_sh` devices run generated day0 scripts through `netlab initial`
     - reconstructs `node_files/` locally from per-node ConfigMaps
     - runs netlab runtime apply (`netlab initial` and netlab-native config modules)

### Runtime-local writable startup persistence

- Netlab remains the source of truth for initial bring-up mode selection. Skyforge does not rewrite startup-vs-shell behavior in `netlab.py`.
- For eligible container-backed KNE runtimes, the generated startup config is treated as a **seed**:
  - the seed file stays read-only and topology-backed
  - KNE creates a per-node PVC in the deployment namespace
  - an init container copies the seed into the writable runtime volume only when the active file does not already exist
  - the live node then writes to that deployment-local startup location
- This preserves traditional CLI workflows such as `write memory` / `copy run start` for the lifetime of the same deployment.
- Delete/recreate still resets the node back to the stock netlab-generated seed because the namespace-scoped PVC is dropped with the runtime namespace.
- No live CLI save writes back to topology YAML, blueprint repos, or designer sidecar files.
- Current safe-path support is limited to container runtimes with a dedicated startup directory (`/mnt/flash`, `/config`, `/home/evo/configdisk`, `/etc/sonic`, `/config_load`).
- Paths that do not have a safe writable directory contract yet (for example `/`, `/etc`, `/disk0:`) remain on direct seed mounts until they have a validated runtime-native persistence path.
- cEOS uses a repo-owned CEOSLab operator fork for this behavior. Build/push with:
  - `./scripts/build-push-ceoslab-operator.sh --tag <tag>`
  - then set `skyforge.kne.controllers.ceoslab.image=<registry>/arista-ceoslab-operator:<tag>` in Helm values before rollout.

### KubeVirt multi-node contract

- For KubeVirt-backed NOSes, `eth0` remains reserved for management. Generated
  data-plane links must start at `eth1`; otherwise KNE meshnet peer resolution
  and Multus attachment ordering break for VM-backed nodes.
- When KNE meshnet is enabled on a Cilium-based cluster, Cilium must not run in
  exclusive CNI mode.
  - `kube-system/cilium-config` must set `cni-exclusive: "false"`.
  - Otherwise Cilium renames `00-meshnet.conflist` to
    `00-meshnet.conflist.cilium_bak`, meshnet never enters the pod sandbox CNI
    chain, `Topology.status` stays empty, and multi-node links remain stuck at
    `Connected 1 interfaces out of 2`.
  - Bootstrap/deploy guardrails should restore active
    `00-meshnet.conflist` after the `meshnet` DaemonSet finishes rolling out if
    Cilium or a prior repair renamed it away. Without that active chained CNI
    file, container labs only get `eth0` and stay stuck at
    `Connected 1 interfaces out of N`.
  - On K3s agent nodes, kubelet may read CNI configs from
    `/var/lib/rancher/k3s/agent/etc/cni/net.d` instead of `/etc/cni/net.d`.
    Guardrails must validate and repair both directories when present; fixing
    only `/etc/cni/net.d` can still leave new lab pods with just `eth0`.
  - The host-level `multus.kubeconfig` must point at a reachable control-plane
    endpoint, not a ClusterIP that is unreachable from the node host network.
- KubeVirt FortiOS images should use the Skyforge-native image naming scheme
  `ghcr.io/forwardnetworks/kubevirt/fortios:<tag>` instead of `vr-*` image
  names. That keeps runtime metadata and UI labels aligned with the actual
  KubeVirt execution path.
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
- Skyforge does not implement per-device initial-policy or SSH-auth gating for kne/netlab apply;
  those checks are owned by netlab runtime behavior.

## Open questions

1) **CRD API shape**
   - What exact CRD does our kne controller expect?
   - Can it embed a raw kne YAML, or does it require a transformed schema?

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
     - periodic orphan cleanup for expired or inactive ephemeral runtime namespaces, including namespaces left behind by failed, stopped, lease-stopped, or tombstoned deployments, plus legacy `smoke-*`, `rt-*`, and `user-*` namespaces
   - Stuck `Terminating` namespaces that are explicitly labeled `skyforge.forwardnetworks.com/ephemeral-runtime=true` now have a second-stage force-finalize path after the grace window passes.

## Implementation checklist (Skyforge)

- Server (encore/Go)
  - Deployment family/engine: `kne` / `netlab`.
  - Runner flow:
    - sync template → runner workdir
    - `netlab create` → `netlab clab-tarball`
    - create per-node ConfigMaps for `node_files/`
    - create kne `Topology` CR embedding `clab.yml`
    - wait for readiness
  - Destroy flow:
    - delete `Topology` CR
    - delete generated ConfigMaps

- Portal
  - Ensure deployment creation uses `family` + `engine` (`kne` / `netlab`) for this path.

- Helm / cluster
  - Ensure kne controller installed and CRDs present in the cluster.
  - Decide where controller runs (namespace) and what RBAC is needed.

## Netlab plugin migration direction

The current `kne/netlab` path keeps Skyforge as orchestrator while netlab
runtime owns native netlab artifacts (`netlab create` + `netlab initial`) and
kne CR apply sequencing.

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
