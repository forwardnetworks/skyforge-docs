# Post-install verification (kubectl only)

This checklist is intended to quickly validate cluster wiring without relying on the retired automated E2E harness.

## Pods ready
```bash
kubectl -n skyforge get pods
```

## Automated gate suite (recommended)

Run these from the repo root to enforce release-controlled health/exposure gates:

```bash
./scripts/preflight-upgrade.sh
./scripts/post-upgrade-gates.sh
```

What these gates enforce:
- required secrets/CRDs present before upgrade
- node scheduling safety (no unintended cordons)
- forward session bridge path (`/api/forward/session`, `/__skyforge/forward/session`) is not `5xx`
- Gateway/HTTPRoute acceptance/programming health
- Skyforge VIP holder verification: force the L2 lease across each eligible node
  and confirm `GET /` succeeds for the announced VIP on every holder
- exposure guardrail: only intended external service and hostnames
- worker/dex spread across nodes

## Cilium Gateway API objects present
```bash
kubectl -n skyforge get gateway,httproute
kubectl -n skyforge get gateway skyforge -o jsonpath='{range .status.conditions[*]}{.type}={.status}{" ("}{.reason}{")\n"}{end}'
kubectl -n skyforge get svc cilium-gateway-skyforge
```

Expected for the local Skyforge VIP path:
- `Gateway` is `Programmed=True`
- `cilium-gateway-skyforge` is exposed as a `LoadBalancer`
- the reserved LB-IPAM / L2-announced VIP is assigned (for example `10.128.16.80`)
- `kubectl -n kube-system get cm cilium-config -o yaml | grep enable-l2-announcements`
  shows `"true"` for clusters that rely on the reserved VIP
- `kubectl get lease -A | grep cilium-l2announce` shows an active L2 lease holder
  for the announced VIP

If `Programmed=False (AddressNotAssigned)`, treat that as a broken exposure
path rather than an expected state.

If the VIP is assigned but no node answers ARP for it, treat that as a broken
Cilium L2 announcement state even if in-cluster requests still work.

## ConfigMap wiring
```bash
kubectl -n skyforge get configmap skyforge-config -o yaml
```

## Health endpoints (inside cluster)
```bash
kubectl -n skyforge run skyforge-health --rm -i --restart=Never --image=curlimages/curl -- \
  sh -lc 'curl -fsS http://skyforge-server:8085/api/health'
```

## External edge sanity (from a trusted workstation)
```bash
curl -kI https://skyforge.local.forwardnetworks.com/
curl -k https://skyforge.local.forwardnetworks.com/dex/.well-known/openid-configuration
```

## Sidebar route sanity (no browser)
Run the sidebar link probe from the repo root:

```bash
./scripts/check-sidebar-links.sh https://skyforge.local.forwardnetworks.com
```

Expected:
- `/fwd` returns `302` to the configured browser-login entry:
  - local mode: `/status?signin=1&next=%2Ffwd%2F` (login UI links to `/login/local`)
  - oidc mode: `/api/auth/oidc/login?next=%2Ffwd%2F`
- Tool links either return a login redirect (`302`) or an app response (`200`) depending on auth state.

## Quick SSO sanity (no browser)
This validates that the Skyforge server can mint sessions and that protected services are reachable.

```bash
kubectl -n skyforge get secret skyforge-admin-shared dex-google-client-secret proxy-tls
kubectl -n skyforge get deploy skyforge-server skyforge-server-worker dex db gitea s3gw
```

## Queue / worker sanity (recommended)
From a logged-in admin session, verify task queue diagnostics are healthy:

```bash
curl -k https://skyforge.local.forwardnetworks.com/api/admin/tasks/diag
```

Expected at idle:
- `status` is `ok`
- `queued=0`
- `running=0`
- `publishFailures10m=0`
- `stuckQueuedCandidates=0`

Confirm queue topology + scale path:
```bash
kubectl -n skyforge get deploy nsq skyforge-server-worker
kubectl -n skyforge get hpa skyforge-server-worker
```

Expected:
- `nsq` stays singleton (`READY 1/1`).
- worker deployment can scale (fixed replicas and/or HPA), depending on values.

## Forward capacity self-heal + stale signals
Capacity rollups and Forward network insights now self-refresh through Encore cron jobs.

Verify cron endpoints are healthy from inside the cluster:

```bash
kubectl -n skyforge run skyforge-capacity-cron-check --rm -i --restart=Never --image=curlimages/curl -- \
  sh -lc 'curl -fsS -X POST http://skyforge-server:8085/internal/cron/capacity/rollups && \
          curl -fsS -X POST http://skyforge-server:8085/internal/cron/capacity/insights/refresh && \
          curl -fsS -X POST http://skyforge-server:8085/internal/cron/capacity/signals/metrics'
```

If managed observability is enabled, verify stale-signal metrics in Prometheus:

```bash
kubectl -n skyforge port-forward svc/skyforge-prometheus 9090:9090
curl -sS 'http://127.0.0.1:9090/prometheus/api/v1/query?query=skyforge_forward_capacity_signal_stale_current'
```

## Platform inventory snapshot + API pressure guardrails
Platform overview and lab-capacity reads are backed by a Postgres inventory
snapshot refreshed by the worker cron, not by request-time cluster-wide `pods`
and `nodes` list calls.

Verify the worker cron and the Prometheus-exported freshness metrics:

```bash
curl -k https://skyforge.local.forwardnetworks.com/api/admin/tasks/diag
kubectl -n skyforge port-forward svc/skyforge-prometheus 9090:9090
curl -sS 'http://127.0.0.1:9090/prometheus/api/v1/query?query=skyforge_platform_inventory_snapshot_age_seconds'
curl -sS 'http://127.0.0.1:9090/prometheus/api/v1/query?query=skyforge_platform_inventory_control_plane_lab_pods_current'
```

Expected:
- snapshot age stays low in steady state (typically under a few minutes)
- control-plane lab pod count remains `0`

## Yaade sanity (optional)
```bash
kubectl -n skyforge rollout status deploy/yaade
```

## Forward analytics strict gate (API)
Run direct API checks for the full analytics API flow:
- `/api/forward/cloud/*`
- `/api/forward/security/*`
- `/api/forward/routing/*`
- `/api/forward/capacity/*`

Competitive gate assertions enforced by this check:
- Cloud: overall `>= 90`, freshness/drift `>= 4`
- Security: overall `>= 90`, freshness/drift `>= 4`
- Routing: overall `>= 88`, freshness/drift `>= 4`
- Capacity: overall `>= 85`, freshness/drift `>= 3`
- All modules require:
  - `coverage >= 4`
  - `explainability >= 4`
  - `actionability >= 4`
  - `evidenceDepth >= 4`
  - `competitiveGatePassed=true`
  - `competitiveTier in {leader,strong}`
  - priorities include rationale/recommendations/evidence

```bash
curl -k "https://skyforge.local.forwardnetworks.com/api/forward/cloud/summary?networkId=<id>&snapshotId=<id>"
curl -k "https://skyforge.local.forwardnetworks.com/api/forward/security/summary?networkId=<id>&snapshotId=<id>"
curl -k "https://skyforge.local.forwardnetworks.com/api/forward/routing/summary?networkId=<id>&snapshotId=<id>"
curl -k "https://skyforge.local.forwardnetworks.com/api/forward/capacity/summary?networkId=<id>&snapshotId=<id>"
```
