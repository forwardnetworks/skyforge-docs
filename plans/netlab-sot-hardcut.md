# Netlab SoT Hard Cut

## Scope
- Remove runtime/table-scrape fallbacks in Forward sync paths.
- Make generated netlab catalog the only source for device credentials, readiness metadata, and Forward type mapping.
- Use DB-backed node status contract for `netlab-c9s` Forward sync.

## Contract Decisions
- `sf_netlab_node_status_current` is the authoritative per-deployment node contract for `netlab-c9s`.
- `forward_type` is generated into `netlab_device_defaults.json`; runtime static maps are removed.
- Legacy non-c9s auto forward sync from parsed `netlab status` output is removed.

## Iteration Loop
1. Generate deploy graph + snapshot mapping.
2. Persist `sf_netlab_node_status_current` rows.
3. Run Forward sync from DB contract (no text parsing).
4. Fail closed when catalog metadata is missing.
5. Run focused tests and drift checks.

## Current Pass
- Added migration for `sf_netlab_node_status_current` and dropped `sf_forward_device_types`.
- Added DB helpers to write/read/delete current node status rows.
- Switched `forward-sync` task to DB contract for `netlab-c9s`.
- Removed legacy Skyforge netlab text-parser/sync path (`syncForwardNetlabDevices`, ANSI table parsing helpers).
- `netlab-c9s` forward-sync now uses only the DB-backed node status contract + topology graph path.
- Moved Forward type mapping to generated catalog metadata (`forward_type`).
- Removed duplicate API-side netlab catalog artifact; taskengine embedded catalog is now the single generated runtime source.
- Propagated canonical `device_key` from `netlab.snapshot.yml` into topology graph state and made readiness/Forward-sync consumers prefer that key over kind/image re-resolution.
- Hardened `netlab-c9s` runtime to require canonical `device_key` for SSH-readiness and Forward sync node resolution (no kind/image fallback in the c9s path).
- Added `forward_type` to `sf_netlab_node_status_current` and hardened `netlab-c9s` Forward sync to require DB-provided `forward_type` (no runtime forward-type re-resolution in c9s path).
- Hardened c9s credential resolution to `device_key`-only catalog lookup (no image-prefix credential fallback in c9s runtime paths).
- Removed snapshot/device fallback and forward-type re-lookup from row persistence; `buildNetlabNodeStatusCurrentRows` now requires canonical graph metadata (`device_key`, `forward_type`) prepared upstream.
- Added DB/runtime contract checks for `sf_netlab_node_status_current` canonical fields (`device_key`, `forward_type`, `kind`, `image`) to prevent silent fallback rows.
- Moved canonical graph enrichment (`device_key`, `forward_type`) into c9s topology artifact capture so persisted `topologyKey` JSON matches DB contract shape.
- Generator/runtime hard-cut updates:
  - catalog now reads `clab_kind` from native netlab locations (`clab.kind` and `clab.node.kind`),
  - no synthetic `netlab_ready` fallback is emitted in generated metadata,
  - no hardcoded readiness retry/delay defaults (parsed from upstream netlab SSH readiness task),
  - c9s/netlab apply orchestration no longer evaluates Skyforge runtime `initial_policy` or SSH/auth gates,
  - netlab runtime now owns apply sequencing and per-device config behavior,
  - c9s deploy prep no longer synthesizes cEOS startup configs or rewrites node bind semantics in taskengine,
  - c9s netlab/validate paths no longer patch topology for pre-runtime device checks.
