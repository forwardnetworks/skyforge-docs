# KNE Model Contract for Netlab-Native Topologies

## Goal

Skyforge emits KNE node `vendor/model/os` from netlab plugin canonical values (no runtime mutation).
KNE should stay minimal and consume canonical models directly.

## Canonical model mapping (plugin-owned)

- EOS -> `vendor=ARISTA`, `model=ceos`, `os=eos`
- IOSXR/XRD -> `vendor=CISCO`, `model=xrd`, `os=ios-xr`
- IOL -> `vendor=CISCO`, `model=iol`, `os=ios`
- IOLL2 -> `vendor=CISCO`, `model=ioll2`, `os=ios`

## KNE responsibilities

1. Implement canonical model behavior (no alias table).
2. Validate model support in vendor node defaults.
3. Keep watcher behavior namespace-scoped for per-topology isolation.

## IOL/IOLL2 support contract

For `model=iol` and `model=ioll2` in KNE Cisco node:

1. `Config.Image` is required (no baked-in `vrnetlab/*` defaults).
2. KNE create/status must work natively.
3. KNE reset/config-push paths follow Cisco workflow parity with model-specific command handling.

## Image build guidance (non-vrnetlab)

Build/publish an IOL runtime image that:

1. Runs the IOL/IOLL2 process as PID 1 (or supervised foreground).
2. Exposes SSH on port 22 for netlab readiness/config paths.
3. Can consume startup config from mounted file path (KNE `config.data`/`config.file` mount).
4. Is published for cluster pull (for example `ghcr.io/<org>/cisco-iol:<tag>`).

See also: `components/docs/kne-iol-image.md`.

## Hard-cut rules

1. No model rewriting in `netlab.py`.
2. No model rewriting in Skyforge taskengine.
3. Startup bootstrap stays in netlab KNE plugin, not in KNE vendor node fallback logic.
