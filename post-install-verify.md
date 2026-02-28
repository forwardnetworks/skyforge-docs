# Post-install verification (kubectl only)

This checklist is intended to quickly validate cluster wiring without relying on the retired automated E2E harness.

## Pods ready
```bash
kubectl -n skyforge get pods
```

## Cilium Gateway API objects present
```bash
kubectl -n skyforge get gateway,httproute
kubectl -n skyforge get gateway skyforge -o jsonpath='{range .status.conditions[*]}{.type}={.status}{" ("}{.reason}{")\n"}{end}'
kubectl -n skyforge get svc cilium-gateway-skyforge
```

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
- `/fwd` returns `302` to `/api/oidc/login?next=%2Ffwd%2F` when unauthenticated.
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
