# KNE Model Alias Contract for Netlab-Native Topologies

## Goal

Skyforge now emits KNE node `vendor/model/os` from netlab-native values (no runtime translation).  
To keep this pure-orchestrator contract, KNE must accept the model strings netlab emits.

## Required fork work (`forwardnetworks/kne`)

1. Add Cisco model aliases in `topo/node/cisco/cisco.go`:
   - `cisco_xrd` -> `xrd`
   - `cisco_iol` -> `xrd` (container IOL path today)
   - `cisco_n9kv` -> supported Cisco model path
   - `cisco_asav` -> supported Cisco model path
2. Keep existing canonical model behavior unchanged.
3. Add unit tests in `topo/node/cisco/cisco_test.go` for each alias.
4. Pin Skyforge netlab runtime image to a KNE commit that includes these aliases.

## Why this is required

- Netlab plugin now preserves source model identity.
- Without KNE aliases, `kne_cli create` fails with `unexpected model` for netlab-native model strings.

## Hard-cut rule

- No model rewriting in `netlab.py`.
- No model rewriting in Skyforge taskengine.
- All model compatibility is owned by the KNE plugin defaults + KNE controller/node implementation.
