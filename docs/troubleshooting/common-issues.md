# Common Issues

## Helm render fails on required secrets

Set required secret values in your values file (or external secret references) before running `helm template`/`helm upgrade`.

## Portal route/runtime mismatch

Regenerate and rebuild frontend assets via portal build workflow; avoid manual route tree edits.

## Forward on-prem endpoint regressions

Re-run proxy route smoke tests for `/fwd` login + key deep links after chart changes.
