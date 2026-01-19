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

## Phase 2 networking model (service DNS)

To avoid coupling configuration to Pod IP churn, Skyforge targets nodes via
stable per-node Service DNS names:

`<topologyName>-<sanitizedNode>.<namespace>.svc`

Skyforge does not rely on Ansible for Netlab C9s post-up configuration.

## Images

Skyforge rewrites generated NOS images (for example, `ceos:*`, `vrnetlab/*`) to
use the `ghcr.io/forwardnetworks/*` mirror so Clabernetes can pull them.
