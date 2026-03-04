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

Runtime defaults are sourced from `components/server/netlab/runtime/defaults.yml`.
Current native mode defaults explicitly force shell config mode for:

- `eos` (`netlab_config_mode: sh`)
- `linux` (`netlab_config_mode: sh`, with `initial/routing: sh`)

Skyforge does not override these per deployment.

## Deployment environment overrides

- The Deployments UI environment-variable editor includes a preset key:
  - `NETLAB_DEVICE`
- `NETLAB_DEVICE` values are shown as a dropdown sourced from the generated netlab
  device catalog (`supported_in_skyforge`, excluding alias-only entries).
- On deploy/validate, Skyforge passes `NETLAB_DEVICE` into the netlab runtime job.
- The netlab runtime applies this as `defaults.device` in `topology.yml` before
  `netlab create`.
- Invalid values fail closed before deployment starts (with the supported device
  list in the error).

## Phase 2 networking model (service DNS)

To avoid coupling configuration to Pod IP churn, Skyforge targets nodes via
stable per-node Service DNS names:

`<topologyName>-<sanitizedNode>.<namespace>.svc`

Skyforge does not implement device-specific post-up config logic for Netlab C9s;
that behavior is delegated to netlab runtime.

## XRd note

For `iosxr`/`cisco_xrd`, container bootstrap environment wiring is handled by
Clabernetes deployment rendering. Skyforge does not launch or configure XRd
directly; it orchestrates the netlab runtime job and Clabernetes topology CR.

## Images

Skyforge rewrites generated NOS images (for example, `ceos:*`, `vrnetlab/*`) to
use the `ghcr.io/forwardnetworks/*` mirror so Clabernetes can pull them.

For Cumulus VX in native mode, Skyforge pins the netlab default image to:

- `ghcr.io/forwardnetworks/networkop-cx:5.3.0` (mirror of `networkop/cx:5.3.0`)
