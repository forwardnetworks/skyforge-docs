# Skyforge E2E Device Reachability Status

Last updated: 2026-02-19T11:01:02Z

Scope: baseline **deploy + SSH reachability** for each onboarded Netlab device type (netlab-c9s → clabernetes + vrnetlab hybrid).

Legend: ✅ pass · ❌ fail · ⏭ skipped · ❔ unknown

| Device type | Status | Updated | Notes |
| --- | --- | --- | --- |
| `arubacx` | ❌ | 2026-02-19T10:36:01Z | deployment failed |
| `asav` | ❌ | 2026-02-19T10:38:18Z | deployment failed |
| `cat8000v` | ❌ | 2026-02-19T10:40:29Z | deployment failed |
| `csr` | ❌ | 2026-02-19T10:41:45Z | deployment failed |
| `cumulus` | ❌ | 2026-02-19T10:42:34Z | deployment failed |
| `dellos10` | ❌ | 2026-02-19T10:42:34Z | deployment failed |
| `eos` | ❌ | 2026-02-19T10:43:01Z | deployment failed |
| `fortios` | ❌ | 2026-02-19T10:45:49Z | deployment failed |
| `iol` | ❌ | 2026-02-19T10:48:01Z | deployment failed |
| `iosv` | ❌ | 2026-02-19T10:48:12Z | deployment failed |
| `iosvl2` | ❌ | 2026-02-19T10:50:01Z | deployment failed |
| `linux` | ❌ | 2026-02-19T10:52:13Z | deployment failed |
| `nxos` | ❌ | 2026-02-19T10:52:54Z | deployment failed |
| `sros` | ❌ | 2026-02-19T10:55:15Z | deployment failed |
| `vjunos-router` | ❌ | 2026-02-19T10:57:12Z | deployment failed |
| `vjunos-switch` | ❌ | 2026-02-19T10:57:13Z | deployment failed |
| `vmx` | ❌ | 2026-02-19T11:01:01Z | deployment failed |
| `vptx` | ❌ | 2026-02-19T11:01:02Z | deployment failed |

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
