# Architecture Overview

Skyforge is composed of:

- `components/server`: Encore/Go backend,
- `components/portal`: TanStack Router + React frontend,
- `components/charts`: Kubernetes/Helm deployment model,
- `vendor/netlab` and `vendor/clabernetes`: pinned integration forks.

Ingress is provided via Cilium Gateway API, with selected integration proxies where needed.
