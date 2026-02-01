# Skyforge E2E Device Reachability Status

Last updated: 2026-02-01T18:10:52Z

Scope: baseline **deploy + SSH reachability** for each onboarded Netlab device type (netlab-c9s → clabernetes + vrnetlab hybrid).

Legend: ✅ pass · ❌ fail · ⏭ skipped · ❔ unknown

| Device type | Status | Updated | Notes |
| --- | --- | --- | --- |
| `arubacx` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `asav` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `cat8000v` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `csr` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `cumulus` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `dellos10` | ❔ | 2026-02-01T00:00:00Z | requires vrnetlab qcow2 |
| `eos` | ✅ | 2026-02-01T18:04:13Z | deploy+ssh ok |
| `fortios` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `iol` | ✅ | 2026-02-01T18:10:52Z | deploy+ssh ok |
| `iosv` | ❔ | 2026-02-01T00:00:00Z | pinned to deterministic ssh tag |
| `iosvl2` | ❔ | 2026-02-01T00:00:00Z | pinned to deterministic ssh tag |
| `linux` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `nxos` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `sros` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `vjunos-router` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `vjunos-switch` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `vjunosevolved` | ❔ | 2026-02-01T00:00:00Z | needs qcow2 (iso not supported by vrnetlab) |
| `vmx` | ❔ | 2026-02-01T00:00:00Z | not yet run |

## How to run

Run from `skyforge-private/server`:

```bash
SKYFORGE_E2E_DEPLOY=true \
SKYFORGE_E2E_SSH_PROBE_MODE=api \
SKYFORGE_E2E_DEVICE_SET=all \
go run ./cmd/e2echeck --run-generated
```

Notes:
- `SKYFORGE_E2E_SSH_PROBE_MODE=api` uses Skyforge’s `/api/admin/e2e/sshprobe` endpoint (fast, no dependency on a running Forward collector).
- If a device fails, inspect its `ws-e2e-*` namespace and the `clabernetes-launcher-*` logs first.
