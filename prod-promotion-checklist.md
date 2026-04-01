# Prod Promotion Checklist

Use this checklist before promoting Skyforge changes validated on the supported single-node k3s workflow to pre-prod or prod.

## 1. Config and render gates

Run the production-readiness gate from the meta repo root:

```bash
./scripts/check-prod-promotion-readiness.py \
  components/charts/skyforge/values.yaml \
  components/charts/skyforge/values-prod-skyforge-local.yaml \
  deploy/examples/values-local-k3s.yaml
```

Expected:
- promotion-readiness script passes
- CI / GitHub Actions `Edition Contract Evidence` job uploads edition artifacts for traceability
- staged features are explicitly pinned in prod values

## 2. Staged feature promotion gates

Before enabling staged integrations in prod values:
- define explicit `enabled` toggles in the prod values file
- pin image tags and secrets in prod values
- provide a rollback plan

## 3. Forward DB/org automation rules

Prod and local use the same default support/org behavior:
- on-prem org `ORG_TYPE=INTERNAL`
- on-prem org `ENFORCE_LICENSING=false`
- support user `forward` enabled by default

Prod deploy script behavior:
- `scripts/deploy-skyforge-prod-safe.sh` applies these defaults automatically by default

## 4. Pre-prod validation

Run one pre-prod environment with prod auth and real ingress before prod cut:
1. deploy chart with prod-auth values
2. validate routes
3. validate deployment create/bring-up/destroy
4. validate Forward route and collector/runtime actions when Forward is enabled

## 5. Promotion decision

Promote only when all are true:
- promotion-readiness script passes
- pre-prod validation pass is documented
- staged feature toggles are explicit for the target environment
- rollback plan is prepared and tested
