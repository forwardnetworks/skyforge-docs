---
harness_kind: completed-exec-plan
status: completed
legacy_source: codex-handoff-2026-04-25-connectivity-and-ai-routing-validation.md
converted_at: 2026-04-27
archived_at: 2026-04-27
environment: prod+qa
title: Prod/QA connectivity and AI routing validation
systems_touched: Environment connectivity, RTK AI routing, context guards
verification: preserved in converted legacy body
current_truth: components/docs/harnesses/environment-contracts.md
superseded_assumptions: see the Harness conversion notes and body sections for stale local/k3d/prod context details
archive_note: historical evidence only; use current_truth for active guidance
---

# Prod/QA connectivity and AI routing validation

> Archived evidence note: this body is retained for provenance only. Use the `current_truth` frontmatter and the completed-plan stub for active guidance.
> Absorbed into active docs on 2026-04-27: current prod/QA connectivity, context guards, and local AI routing checks live in `components/docs/harnesses/environment-contracts.md`.

# Skyforge Handoff - Prod/Dev Connectivity + AI Routing Validation

Date: 2026-04-25
Validation host/time: `/home/captainpacket/src/skyforge` at `2026-04-25T13:55:30-05:00` (America/Chicago)

## Scope

- Validate connectivity to both environments:
  - Prod: `https://skyforge.dc.forwardnetworks.com`
  - Dev: `https://skyforge.local.forwardnetworks.com`
- Validate local AI harness routing for:
  - `rtk ai-local`
  - `rtk ai-gemini`
  - `rtk ai-claude`
  - `rtk ai-delegate local|gemini|claude`

## Preconditions Verified

```bash
rtk --version
which rtk
```

Observed:

- `rtk 0.37.2`
- `/usr/bin/rtk`

## Connectivity Validation

DNS resolution checks:

```bash
rtk bash -lc "getent ahosts skyforge.dc.forwardnetworks.com | head -n 3"
rtk bash -lc "getent ahosts skyforge.local.forwardnetworks.com | head -n 3"
```

Observed:

- Prod DNS: `10.128.65.100`
- Dev DNS: `10.128.16.80`

HTTPS health checks:

```bash
rtk bash -lc "curl -skS -o /tmp/skyforge_prod_health.json -w '%{http_code} %{remote_ip} %{time_total}\n' https://skyforge.dc.forwardnetworks.com/api/health"
rtk bash -lc "curl -skS -o /tmp/skyforge_dev_health.json -w '%{http_code} %{remote_ip} %{time_total}\n' https://skyforge.local.forwardnetworks.com/api/health"
rtk bash -lc "jq -c . /tmp/skyforge_prod_health.json"
rtk bash -lc "jq -c . /tmp/skyforge_dev_health.json"
```

Observed:

- Prod: `200 10.128.65.100 0.249770`
- Dev: `200 10.128.16.80 0.246494`
- Prod payload: `{"status":"ok","time":"2026-04-25T18:55:38Z"}`
- Dev payload: `{"status":"ok","time":"2026-04-25T18:55:38Z"}`

Conclusion:

- Connectivity and route-to-service are healthy for both prod and dev from this host.

## AI Routing Validation

Direct command routing checks:

```bash
rtk ai-local "Reply with exactly: ROUTE_OK local"
rtk ai-gemini "Reply with exactly: ROUTE_OK gemini"
rtk ai-claude "Reply with exactly: ROUTE_OK claude"
```

Observed:

- `ROUTE_OK local`
- `ROUTE_OK gemini`
- `ROUTE_OK claude`

Delegate front-door routing checks:

```bash
rtk ai-delegate local "Reply with exactly: DELEGATE_OK local"
rtk ai-delegate gemini "Reply with exactly: DELEGATE_OK gemini"
rtk ai-delegate claude "Reply with exactly: DELEGATE_OK claude"
```

Observed:

- `DELEGATE_OK local`
- `DELEGATE_OK gemini`
- `DELEGATE_OK claude`

Notes:

- Gemini invocations emitted terminal capability warnings (`TERM=dumb`, no 256-color), but calls completed successfully and returned expected output.
- Routing behavior is validated functionally by distinct successful responses across all three backends and the `ai-delegate` selector path.

## Context Guard Parity (QA + PROD)

Guard hardening added:

- `scripts/lib/environment-context.sh` now infers target env from `VALUES_FILE` when `SKYFORGE_TARGET_ENV` is not set.
- QA now fails closed if a prod values file is supplied.
- PROD now fails closed if a qa values file is supplied.

This keeps both directions symmetric during context switches.

Validation matrix run (using temporary context file so live user context is untouched):

```bash
rtk bash -lc '
set -euo pipefail
ROOT=/home/captainpacket/src/skyforge
TMP_CTX="$(mktemp /tmp/skyforge-context-test.XXXX)"
source "$ROOT/scripts/lib/environment-context.sh"

SKYFORGE_ACTIVE_CONTEXT_FILE="$TMP_CTX" skyforge_write_active_context qa
SKYFORGE_ACTIVE_CONTEXT_FILE="$TMP_CTX" SKYFORGE_TARGET_ENV=qa VALUES_FILE=values-qa-skyforge-local.yaml SKYFORGE_PUBLIC_BASE_URL=https://skyforge.local.forwardnetworks.com SKYFORGE_FORWARD_PUBLIC_BASE_URL=https://skyforge-fwd.local.forwardnetworks.com REMOTE=arch@skyforge-worker-0 skyforge_require_active_context qa
! SKYFORGE_ACTIVE_CONTEXT_FILE="$TMP_CTX" SKYFORGE_TARGET_ENV=prod VALUES_FILE=values-prod-labpp-sales-prod01.yaml SKYFORGE_PUBLIC_BASE_URL=https://skyforge.dc.forwardnetworks.com SKYFORGE_FORWARD_PUBLIC_BASE_URL=https://skyforge-fwd.dc.forwardnetworks.com REMOTE=arch@labpp-sales-prod01.dc.forwardnetworks.com skyforge_require_active_context prod

SKYFORGE_ACTIVE_CONTEXT_FILE="$TMP_CTX" skyforge_write_active_context prod
SKYFORGE_ACTIVE_CONTEXT_FILE="$TMP_CTX" SKYFORGE_TARGET_ENV=prod VALUES_FILE=values-prod-labpp-sales-prod01.yaml SKYFORGE_PUBLIC_BASE_URL=https://skyforge.dc.forwardnetworks.com SKYFORGE_FORWARD_PUBLIC_BASE_URL=https://skyforge-fwd.dc.forwardnetworks.com REMOTE=arch@labpp-sales-prod01.dc.forwardnetworks.com skyforge_require_active_context prod
! SKYFORGE_ACTIVE_CONTEXT_FILE="$TMP_CTX" SKYFORGE_TARGET_ENV=qa VALUES_FILE=values-qa-skyforge-local.yaml SKYFORGE_PUBLIC_BASE_URL=https://skyforge.local.forwardnetworks.com SKYFORGE_FORWARD_PUBLIC_BASE_URL=https://skyforge-fwd.local.forwardnetworks.com REMOTE=arch@skyforge-worker-0 skyforge_require_active_context qa

! SKYFORGE_ACTIVE_CONTEXT_FILE="$TMP_CTX" SKYFORGE_TARGET_ENV=qa VALUES_FILE=values-prod-labpp-sales-prod01.yaml SKYFORGE_PUBLIC_BASE_URL=https://skyforge.local.forwardnetworks.com SKYFORGE_FORWARD_PUBLIC_BASE_URL=https://skyforge-fwd.local.forwardnetworks.com REMOTE=arch@skyforge-worker-0 skyforge_require_active_context qa
! SKYFORGE_ACTIVE_CONTEXT_FILE="$TMP_CTX" SKYFORGE_TARGET_ENV=prod VALUES_FILE=values-qa-skyforge-local.yaml SKYFORGE_PUBLIC_BASE_URL=https://skyforge.dc.forwardnetworks.com SKYFORGE_FORWARD_PUBLIC_BASE_URL=https://skyforge-fwd.dc.forwardnetworks.com REMOTE=arch@labpp-sales-prod01.dc.forwardnetworks.com skyforge_require_active_context prod

test "$(SKYFORGE_TARGET_ENV= VALUES_FILE=values-qa-skyforge-local.yaml skyforge_detect_target_env)" = "qa"
test "$(SKYFORGE_TARGET_ENV= VALUES_FILE=values-prod-labpp-sales-prod01.yaml skyforge_detect_target_env)" = "prod"
rm -f "$TMP_CTX"
'
```

Observed: all assertions passed.

## Handoff Summary

- Prod connectivity: PASS
- Dev connectivity: PASS
- Local model route: PASS
- Gemini route: PASS
- Claude route: PASS
- Delegate router (`local|gemini|claude`): PASS
- QA/PROD context guard parity (including values-file mismatch guard): PASS

## Re-run Checklist

Use these exact commands for fast re-validation:

```bash
cd /home/captainpacket/src/skyforge
rtk bash -lc "curl -skS -o /tmp/skyforge_prod_health.json -w '%{http_code} %{remote_ip} %{time_total}\n' https://skyforge.dc.forwardnetworks.com/api/health"
rtk bash -lc "curl -skS -o /tmp/skyforge_dev_health.json -w '%{http_code} %{remote_ip} %{time_total}\n' https://skyforge.local.forwardnetworks.com/api/health"
rtk ai-delegate local "Reply with exactly: DELEGATE_OK local"
rtk ai-delegate gemini "Reply with exactly: DELEGATE_OK gemini"
rtk ai-delegate claude "Reply with exactly: DELEGATE_OK claude"
```
