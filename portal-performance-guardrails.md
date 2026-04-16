# Portal Performance Guardrails

These rules keep Skyforge fast without drifting away from its existing source-of-truth and runtime model.

## Data ownership

- Postgres remains the source of truth for tasks, lifecycle, deployments, and runs.
- NSQ remains the singleton transport for Encore pubsub delivery. Scale workers and worker concurrency, not NSQ replicas.
- Redis is cache-only. Use it for derived, non-authoritative data that is safe to expire and recompute.

## Portal routing

- Prefer TanStack file-route lazy companions (`*.lazy.tsx`) for heavy pages.
- Keep critical route contracts in the route file:
  - `validateSearch`
  - `beforeLoad`
  - `loaderDeps`
  - `loader`
- Keep render-heavy imports in the lazy companion so the main shell stays small.

## Query ownership

- Prefer route-owned queries and route loaders over dashboard-wide aggregate dependencies.
- Use `ensureQueryData` in route loaders when the route needs predictable warm data for the first render.
- Do not make detail pages depend on broad dashboard aggregates when a narrower read model exists or can be added.

## Invalidation

- Default to targeted invalidation:
  - affected deployment detail keys
  - affected user-scope deployments list
  - affected user-scope runs list
- Only invalidate dashboard aggregate queries when the current page still depends on them.
- Avoid using dashboard aggregate invalidation as a catch-all mutation side effect.

## Root-shell fetches

- Keep root-owned queries minimal.
- If a root component only needs cached data, subscribe to the cache without forcing an eager fetch from the root shell.

## Rollout discipline

- Performance changes should stay inside supported patterns:
  - TanStack Router lazy routes and loaders
  - TanStack Query cache ownership and targeted invalidation
  - Encore service boundaries, Postgres state, and NSQ-backed workers
- Do not introduce ad hoc coordination layers or alternate sources of truth just to hide latency.
