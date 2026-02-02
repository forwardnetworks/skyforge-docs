# Skyforge E2E Device Reachability Status

Last updated: 2026-02-02T10:22:13Z

Scope: baseline **deploy + SSH reachability** for each onboarded Netlab device type (netlab-c9s → clabernetes + vrnetlab hybrid).

Legend: ✅ pass · ❌ fail · ⏭ skipped · ❔ unknown

| Device type | Status | Updated | Notes |
| --- | --- | --- | --- |
| `arubacx` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `asav` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `cat8000v` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `csr` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `cumulus` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `dellos10` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `eos` | ⏭ | 2026-02-02T08:44:40Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `fortios` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `iol` | ⏭ | 2026-02-02T08:44:40Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `iosv` | ❌ | 2026-02-02T09:07:34Z | deployment failed |
| `iosvl2` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `linux` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `nxos` | ✅ | 2026-02-02T10:22:13Z | deploy+ssh ok |
| `sros` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `vjunos-router` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `vjunos-switch` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `vmx` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `vptx` | ⏭ | 2026-02-02T01:37:34Z | skipped by SKYFORGE_E2E_DEVICES filter |

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
