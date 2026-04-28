# Netlab → KNE (experimental)

Goal: use `netlab` to generate a KNE topology + node artifacts, and run the resulting topology on Kubernetes using the **kne** controller (referred to as “kne” in Skyforge).

Contract note:
- Skyforge KNE uses top-level `provider: kne`, supplied by runtime defaults
  when the selected topology omits `provider`.
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
  - waiting for topology readiness and realized KNE data interfaces
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

### IOL/IOLL2 startup-mode contract

IOL and IOL-L2 devices must use netlab startup configuration mode in KNE
deployments. Do not edit individual training or quick-deploy topologies to
force this behavior; keep topology files light and configure the shared behavior
through netlab defaults and runtime contracts.

Canonical source:

- `components/server/netlab/runtime/defaults.yml`
- IOL/IOL-L2 device defaults set `netlab_config_mode: startup`

Mixed-NOS topology behavior:

- Startup-config nodes stay on topology-backed startup config.
- Generated day-0 nodes still run through `netlab initial`.
- When both are present, runtime must call `netlab initial` with `--limit`
  containing only generated-day0 nodes.
- IOL/IOL-L2 nodes must not be sent through Ansible `deploy-config/ios.yml`.

Worker log validation:

```bash
KUBECONFIG=/tmp/kubeconfig-prod-labpp \
  kubectl -n skyforge logs deploy/skyforge-server-worker --since=60m | \
  rg 'netlab initial args|deploy-config/ios.yml|operation requires privilege escalation'
```

Expected:

- `netlab initial args` includes `--limit` when a mixed topology has generated
  day-0 nodes.
- The limit contains non-IOL generated-day0 nodes only.
- IOL/IOL-L2 nodes are absent from `deploy-config/ios.yml` log lines.
- No `operation requires privilege escalation` failures are present.

Validated prod evidence from the 2026-04-27 repair:

- Deployment: `ea88f8f6-9001-4957-958c-febd6c05c008`
- Deploy task: `3209`
- Log line: `netlab initial args: --fast --limit core1,core2,dist2`
- Forward sync task: `3210`
- Forward result: 6 devices uploaded for network `399`

The runtime image that included the apply-limit repair was:

- `ghcr.io/forwardnetworks/skyforge-netlab:20260427-iol-startup-limit-r1`

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
- `ENCORE_CFG_*` secret payloads are base64url raw without padding after the
  Kubernetes secret data layer is decoded. Do not patch these config blobs with
  standard base64; server and worker pods can crash with config decode panics.
  Prefer Helm values and `scripts/deploy-skyforge-env.sh` for routine changes.
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

Forward host visibility depends on network-device evidence, not endpoint
collection alone. The Forward host computation uses MAC-table entries as
candidate hosts, ARP tables to attach IP addresses to those MACs, and then
keeps only candidates learned on edge ports. Endpoint collection can enrich an
already detected host with endpoint metadata, but it does not create the
`DeviceHost` by itself.

The Skyforge Linux host runtime must therefore generate traffic that causes
adjacent NOS devices to learn both data sources before Forward collection:

- gratuitous ARP from the host IP, for generic L2/MAC learning
- unicast ARP/ICMP to the netlab-provided gateway or attached router neighbor,
  for gateway ARP-table learning
- broadcast ping as a fallback L2 frame source when no gateway responds

Keep this in the runtime Linux template/defaults layer. Do not edit individual
training or quick-deploy topologies to force host activity.

EOS router nodes need global IPv4 routing enabled before VRF interfaces can
produce the ARP/MAC evidence Forward uses for host detection. If a running cEOS
lab shows host activity processes in the Linux endpoints but no host ARP/MAC
state on the adjacent PE, check these EOS signals first:

- `show running-config | include ^no ip routing|^ip routing`
- `show ip interface EthernetX` should report `IPv4 interface forwarding: enabled`
- `show ip route vrf all connected` should include the host-facing connected
  prefixes
- `show ip arp vrf all` should include the Linux endpoint IP/MAC entries after
  the host activity loop has run

Keep this aligned with upstream netlab behavior. The upstream EOS initial
template gates IPv4 routing on `af.ipv4|default(False) and role != 'host'`.
KNE cEOS shell-mode config should mirror that in the provider EOS `initial.j2`
template. Do not put routing or VRF state in `ceos-bootstrap.j2`; that file is
the minimal startup shim for cEOS management access and shell-mode config
execution. Do not patch individual topology files, and do not depend on late
runtime CLI mutation of cEOS VRF interfaces.

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
   - Successful pod readiness is not sufficient for task success. Runtime and
     taskengine must also verify that each non-management
     `Topology.spec.links[].local_intf` exists inside the corresponding node pod
     before `netlab initial` runs and before a KNE deployment is marked
     successful.
   - If a link is skipped or only one side is realized, fail the deployment with
     `meshnet-link-interface` instead of publishing a Forward collection-ready
     deployment. The expected symptom is missing entries such as `h2:eth1` or
     `pe2:eth2`.
   - Do not fix this class by editing EOS or topology templates. Missing Linux
     host interfaces or missing cEOS peer interfaces are KNE/meshnet realization
     failures, not NOS configuration failures.
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
   - For the MVP, use the Skyforge-authenticated management access bridge
     documented in `management-access.md` instead of exposing node services
     directly outside the cluster.

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
   - V1 uses the authenticated management access bridge in
     `management-access.md`.
   - Future work can add a deployment-scoped bastion if non-SSH or multi-session
     workflows require it.

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
