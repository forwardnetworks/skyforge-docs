# Skyforge E2E Device Reachability Status

Last updated: 2026-02-04T11:27:27Z

Scope: baseline **deploy + SSH reachability** for each onboarded Netlab device type (netlab-c9s → clabernetes + vrnetlab hybrid).

Legend: ✅ pass · ❌ fail · ⏭ skipped · ❔ unknown

| Device type | Status | Updated | Notes |
| --- | --- | --- | --- |
| `arubacx` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `asav` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `cat8000v` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `csr` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `cumulus` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `dellos10` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `eos` | ✅ | 2026-02-04T11:27:27Z | verified manually (run 75). Note: e2e netlab initial SSH check previously flaked |
| `fortios` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `iol` | ✅ | 2026-02-04T11:27:27Z | deploy+ssh ok (e2e taskIds 45/49) |
| `iosv` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `iosvl2` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `linux` | ❔ | 2026-02-01T00:00:00Z | not yet run |
| `nxos` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `sros` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `vjunos-router` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `vjunos-switch` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |
| `vmx` | ✅ | 2026-02-03T12:27:38Z | deploy+ssh ok |
| `vptx` | ⏭ | 2026-02-04T11:16:22Z | skipped by SKYFORGE_E2E_DEVICES filter |

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
