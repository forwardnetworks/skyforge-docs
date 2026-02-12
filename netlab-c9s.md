# Netlab (C9s) workflow

Skyforge's **Netlab (C9s)** deployment method runs Netlab as a generator and
deploys the resulting Containerlab topology via Clabernetes.

## Phases

1. **Generator (netlab create)**: runs inside the workspace namespace using
   `ENCORE_CFG_SKYFORGE.NetlabGenerator.GeneratorImage`.
2. **Clabernetes deploy**: Skyforge sanitizes node names for Kubernetes, then
   deploys the generated `clab.yml`.
3. **Post-deploy config (Go-only)**:
   - Linux nodes: Skyforge runs the netlab-generated `node_files/<node>/{initial,routing}` shell scripts
     directly inside the Linux pods (parallelized).
   - Network OS nodes (e.g. cEOS): base configuration is applied via startup configs mounted at boot time,
     and Skyforge applies any netlab-generated post-up config snippets (cfglets/modules) using Kubernetes exec
     (still Go-only; no Ansible).

## Forward sync behavior

- On Forward network ensure/create, Skyforge updates
  `PATCH /api/networks/{networkId}/performance/settings` to enable global SNMP
  performance collection.
- Skyforge no longer starts Forward connectivity tests explicitly via
  `connectivityTests/bulkStart`.
- After topology/device sync and SSH-readiness gating, Skyforge starts Forward
  collection; Forward then runs its normal connectivity validation as part of
  collection.

Linux node extras (optional, controlled by env vars):

- `SKYFORGE_NETLAB_C9S_LINUX_ENABLE_SSH=true`: enable password-based SSH inside Linux pods (used by Forward endpoints).
- `SKYFORGE_NETLAB_C9S_LINUX_NOISE=true`: start a lightweight background “noise” loop (gratuitous ARP + gateway ping)
  so quiet endpoints still generate L2/L3 activity.

## Phase 2 networking model (service DNS)

To avoid coupling configuration to Pod IP churn, Skyforge targets nodes via
stable per-node Service DNS names:

`<topologyName>-<sanitizedNode>.<namespace>.svc`

Skyforge does not rely on Ansible for Netlab C9s post-up configuration.

## Images

Skyforge rewrites generated NOS images (for example, `ceos:*`, `vrnetlab/*`) to
use the `ghcr.io/forwardnetworks/*` mirror so Clabernetes can pull them.
