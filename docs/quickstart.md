# Quickstart

## Prerequisites

- Kubernetes cluster with Cilium Gateway API support.
- Helm 3.
- Access to Skyforge images.

## Bootstrap

From the meta repo root:

```bash
make bootstrap
make test
```

## Deploy

Use the chart under `components/charts/skyforge` and the environment values file that matches your target environment.

Validate first:

```bash
helm lint components/charts/skyforge
```

## First checks

- Open `/status` in the portal.
- Verify personal account access is available.
- Verify a simple deployment can be queued.
