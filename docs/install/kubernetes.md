# Install on Kubernetes

Skyforge is installed via Helm from `components/charts/skyforge`.

## Required inputs

- image tags for server and worker,
- secret values for session/admin credentials,
- Gateway hostname values.

## Recommended flow

1. Render chart to inspect:

```bash
helm template skyforge components/charts/skyforge -f <values-file>
```

2. Lint chart:

```bash
helm lint components/charts/skyforge -f <values-file>
```

3. Upgrade/install:

```bash
helm upgrade --install skyforge components/charts/skyforge -f <values-file>
```
