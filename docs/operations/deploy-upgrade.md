# Deploy and Upgrade

## Pre-upgrade checklist

- Build/push images.
- Confirm chart values reference new image tags.
- Lint chart and run server/portal checks.

## Upgrade

```bash
helm upgrade --install skyforge components/charts/skyforge -f <values-file>
```

## Post-upgrade smoke checks

- `/status` is healthy.
- Portal routes load.
- Deployment queue accepts and starts a run.
- Forward on-prem integration endpoint behaves as expected when enabled.
