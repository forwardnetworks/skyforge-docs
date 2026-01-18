# Netlab (C9s) workflow

Skyforge's **Netlab (C9s)** deployment method runs Netlab as a generator and
deploys the resulting Containerlab topology via Clabernetes.

## Phases

1. **Generator (netlab create)**: runs inside the workspace namespace using
   `ENCORE_CFG_SKYFORGE.NetlabGenerator.GeneratorImage`.
2. **Clabernetes deploy**: Skyforge sanitizes node names for Kubernetes, then
   deploys the generated `clab.yml`.
3. **Post-deploy config (netlab initial)**: runs as a Kubernetes Job using
   `ENCORE_CFG_SKYFORGE.NetlabGenerator.AnsibleImage`.

## Phase 2 networking model (service DNS)

To avoid coupling configuration to Pod IP churn, Skyforge targets nodes via
stable per-node Service DNS names:

`<topologyName>-<sanitizedNode>.<namespace>.svc`

The ansible runner patches the generated `hosts.yml` accordingly and then runs
`netlab initial`.

## Images

Skyforge rewrites generated NOS images (for example, `ceos:*`, `vrnetlab/*`) to
use the `ghcr.io/forwardnetworks/*` mirror so Clabernetes can pull them.

