# Skyforge Rollout Notes Template

## Change summary
- release/chart revision:
- values bundle source:
- scope (core services only):

## Preconditions (preflight)
- kube context:
- required secrets present:
- required CRDs present:
- scheduling status (unschedulable nodes):

## Execution
```bash
./scripts/preflight-upgrade.sh
helm upgrade --install skyforge ./components/charts/skyforge \
  -n skyforge --create-namespace \
  --atomic --timeout 20m \
  -f <values.yaml> -f <env-values.yaml> -f <secrets.yaml>
./scripts/post-upgrade-gates.sh
```

## Post-upgrade gate results
- Gate 1 (infrastructure):
- Gate 2 (control/data path):
- Gate 3 (exposure):
- Gate 4 (HA spread):

## Blockers and mitigation
- blocker:
- impact:
- mitigation:
- follow-up owner:

## Rollback point
- previous Helm revision:
- rollback command:
```bash
helm -n skyforge rollback skyforge <revision> --wait --timeout 20m
```

## Recovery commands used
```bash
# Include exact commands executed during incident recovery.
```
