# Prod Promotion Checklist

Use this checklist before promoting Skyforge changes validated in local `k3d` to pre-prod/prod.

## 1. Config and render parity gates

Run both gates from the meta repo root:

```bash
./scripts/check-k3d-parity.py \
  components/charts/skyforge/values.yaml \
  components/charts/skyforge/values-prod-skyforge-local.yaml \
  deploy/examples/values-k3d-dev.yaml

./scripts/check-prod-promotion-readiness.py \
  components/charts/skyforge/values.yaml \
  components/charts/skyforge/values-prod-skyforge-local.yaml \
  deploy/examples/values-k3d-dev.yaml
```

Expected:
- no non-approved local-vs-prod diffs
- staged features explicitly pinned in prod values:
  - `skyforge.infoblox.enabled=false`
  - `skyforge.jira.enabled=false`
  - `skyforge.forward.enabled=true`
  - `skyforge.forwardCluster.enabled=true`

## 2. Staged feature promotion gates

Before enabling staged integrations in prod values:
- define explicit `enabled` toggles in the prod values file,
- pin image tags and secrets in prod values,
- provide a rollback plan (disable toggle + known-good image tags).

For current staged integrations:
- `Infoblox`: keep disabled until KubeVirt/Multus runtime and ingress path are validated in pre-prod.
- `Jira`: keep disabled until auth/routing/runtime checks pass in pre-prod.
- `Rapid7`: keep disabled until in-cluster runtime and ingress path checks pass in pre-prod.

## 3. Forward DB/org automation rules

Prod and local now use the same default support/org behavior:
- set on-prem org to `ORG_TYPE=INTERNAL`
- set on-prem org `ENFORCE_LICENSING=false`
- keep support user `forward` enabled by default

Prod deploy script behavior:
- `scripts/deploy-skyforge-prod-safe.sh` applies these defaults automatically by default
- control flags:
  - `FORWARD_APPLY_SUPPORT_DEFAULTS=true|false`
  - `FORWARD_ENABLE_SUPPORT_USER=true|false` (default `true`)
  - `FORWARD_NAMESPACE` (default `forward`)
  - `FORWARD_ONPREM_ORG_ID` (default `101`)

Local helper remains available for manual support operations:
- `scripts/forward-local-support-access.sh`

## 4. Pre-prod validation (required)

Run one pre-prod environment with prod auth and real ingress before prod cut:

1. Deploy chart with prod-auth values (`skyforge.auth.mode=oidc`).
2. Validate routes:
   - `/git`
   - `/coder`
   - `/netbox`
   - `/nautobot`
   - `/api-testing`
3. Validate deployment flow:
   - create
   - bring up
   - destroy
4. Validate Forward path:
   - Forward route reachable
   - collector config and runtime actions
   - sync path from deployment to Forward

Cluster resiliency gate:
- `scripts/deploy-skyforge-prod-safe.sh` now executes `scripts/k8s-network-resilience.sh`
  before and after Helm apply in strict mode.
- Auto-repair of node-local Cilium datapath is opt-in (`SKYFORGE_NETWORK_RESILIENCE_REPAIR=true`).
- Tune only if needed:
  - `SKYFORGE_NETWORK_RESILIENCE_ENABLE=true|false`
  - `SKYFORGE_NETWORK_RESILIENCE_STRICT=true|false`
  - `SKYFORGE_NETWORK_RESILIENCE_REPAIR=true|false`
  - `SKYFORGE_NETWORK_RESILIENCE_MAX_REPAIRS_PER_NODE=<n>`

## 5. Promotion decision

Promote only when all are true:
- parity and promotion-readiness scripts pass
- pre-prod validation pass is documented
- staged feature toggles are explicitly set for the target environment
- rollback plan is prepared and tested
