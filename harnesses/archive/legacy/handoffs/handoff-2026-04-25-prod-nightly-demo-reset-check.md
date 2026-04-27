---
harness_kind: completed-exec-plan
status: completed
legacy_source: codex-handoff-2026-04-25-prod-nightly-demo-reset-check.md
converted_at: 2026-04-27
archived_at: 2026-04-27
environment: prod
title: Nightly demo-org reset validation
systems_touched: Forward demo org reset, task queue, DNS/service resolution
verification: preserved in converted legacy body
current_truth: components/docs/forward-demo-reset-rollout-checklist.md
superseded_assumptions: see the Harness conversion notes and body sections for stale local/k3d/prod context details
archive_note: historical evidence only; use current_truth for active guidance
---

# Nightly demo-org reset validation

> Archived evidence note: this body is retained for provenance only. Use the `current_truth` frontmatter and the completed-plan stub for active guidance.

# Skyforge Handoff - Prod Nightly Demo-Org Reset Validation

Date: 2026-04-25  
Scope: Verify whether prod nightly demo-org reset succeeded; troubleshoot/remediate if not.

## Validation Method

- Authenticated to prod Skyforge API as admin (`skyforge`) using local prod secret file:
  - `deploy/skyforge-secrets-prod-labpp-sales-prod01.yaml`
- Queried:
  - `/api/admin/rbac/users`
  - `/api/admin/forward/orgs/{username}/rebuild/runs`
  - `/api/admin/tasks/diag`

## What Happened

- Nightly reset did run on `2026-04-25T03:17:03Z` / `2026-04-25T03:17:04Z`.
- It failed for the affected demo users (10 users).
- Common failure signature on the nightly runs:
  - `status=failed`
  - `lastStep=reprovisioning`
  - `lastError=unavailable: failed to list forward users`
  - `targetForwardOrgUserLookupError=Get "https://fwd-appserver.forward.svc:8443/api/admin/users": dial tcp: lookup fwd-appserver.forward.svc on 10.43.0.10:53: no such host`

This indicates a DNS/service-resolution failure from Skyforge runtime to the in-cluster Forward service at nightly execution time.

## Troubleshooting Actions Executed

1. Manual validation retry:
- Queued manual retry for `andreaslaquiante` (`trigger=manual-troubleshoot-retry`).
- Run advanced to `reprovisioning` + `seeding-demo` (seed progress reached `4/5`), confirming the earlier failure mode is not an immediate hard-fail now.

2. Recovery fan-out:
- Queued retries (`trigger=manual-post-nightly-recovery`) for failed-nightly users without active runs:
  - `garyberger`
  - `glenturner`
  - `jamesnewton`
  - `jasonhammond`
  - `kevinkuhls`
  - `rudycollado`
  - `seandeveci`
  - `skyforge-user-bootstrap`
  - `zakerhadi`
- Prior manual retry was already queued for `craigjohnson` (`trigger=manual-post-nightly-retry`).

3. Queue guardrails:
- Ran `/api/admin/tasks/reconcile-running` with:
  - `hardMaxRuntimeMinutes=10`
  - `limit=20`
- Result: `consideredTasks=1`, `markedFailed=1`.
- Ran `/api/admin/tasks/reconcile` with:
  - `limit=50`
- Result: `consideredTasks=7`, `republished=7`.

## Current State At Handoff

- `/api/admin/tasks/diag`:
  - `workerEnabled=true`
  - `workerHeartbeatAgeSec` low (worker alive)
  - `running=3` (forward-tenant-reset)
  - `queued=7` (forward-tenant-reset)
  - `status=degraded` due queued stale-candidate signal
- Demo reset retries are queued/running but not fully drained yet.

## Operational Risk

- Nightly did not complete successfully for affected users.
- Recovery retries are in progress but queue still has backlog.
- System is not in a fully recovered state yet for demo-org reset SLI.

## Recommended Immediate Follow-up

1. Keep polling every 2-3 minutes until the retry queue drains:
```bash
python - <<'PY'
import json,yaml,pathlib,urllib.request,http.cookiejar,ssl
BASE="https://skyforge.dc.forwardnetworks.com"
sec=yaml.safe_load(pathlib.Path("deploy/skyforge-secrets-prod-labpp-sales-prod01.yaml").read_text())
pw=sec["secrets"]["items"]["skyforge-admin-shared"]["password"]
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
cj=http.cookiejar.CookieJar()
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj), urllib.request.HTTPSHandler(context=ctx))
def req(m,p,b=None):
    d=None
    if b is not None:
        import json as _j; d=_j.dumps(b).encode()
    r=urllib.request.Request(BASE+p,data=d,headers={"Content-Type":"application/json"},method=m)
    with op.open(r,timeout=30) as resp:
        raw=resp.read().decode()
        return json.loads(raw) if raw else {}
req("POST","/api/auth/login",{"username":"skyforge","password":pw})
print(json.dumps(req("GET","/api/admin/tasks/diag"), indent=2))
PY
```

2. If `queued` remains non-zero with no run transitions, inspect worker/Forward/DNS directly on prod k8s:
- `kubectl -n skyforge get pods`
- `kubectl -n kube-system get pods -l k8s-app=kube-dns`
- `kubectl -n forward get svc,pods`
- worker logs around reset execution window.

3. After drain, re-check each affected user's latest demo reset run status and confirm transitions to `ready`.
