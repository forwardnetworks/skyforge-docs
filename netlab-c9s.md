# Netlab (C9s) workflow

Skyforge's **Netlab (C9s)** deployment method runs Netlab in-cluster and
deploys the resulting Containerlab topology via Clabernetes.

## Phases

1. **Netlab runtime (netlab create)**: runs inside the user namespace using
   `ENCORE_CFG_SKYFORGE.Netlab.Image`.
2. **Clabernetes deploy**: Skyforge sanitizes node names for Kubernetes, then
   deploys the generated `clab.yml`.
3. **Netlab apply phase**:
   - Skyforge invokes the netlab runtime apply job after topology bring-up.
   - Netlab runtime owns post-deploy config behavior (`netlab initial`, cfglets/modules, and
     device-specific apply semantics).

Linux node extras are handled by the C9s runtime path and are not user-configurable overrides.

## Phase 2 networking model (service DNS)

To avoid coupling configuration to Pod IP churn, Skyforge targets nodes via
stable per-node Service DNS names:

`<topologyName>-<sanitizedNode>.<namespace>.svc`

Skyforge does not implement device-specific post-up config logic for Netlab C9s;
that behavior is delegated to netlab runtime.

## Images

Skyforge rewrites generated NOS images (for example, `ceos:*`, `vrnetlab/*`) to
use the `ghcr.io/forwardnetworks/*` mirror so Clabernetes can pull them.

For Cumulus VX in native mode, Skyforge pins the netlab default image to:

- `ghcr.io/forwardnetworks/networkop-cx:5.3.0` (mirror of `networkop/cx:5.3.0`)
