# User-Scoped API Migration

Skyforge is moving from workspace-keyed API routes to canonical user-scoped routes for personal workflows.

## Canonical Personal Route Prefix

- Canonical prefix: `/api/user/workspace`
- Temporary compatibility prefix: `/api/user/scope`
- Legacy prefix (deprecated): `/api/workspaces/:id`

For personal scope, use `/api/user/workspace/...`.

## Compatibility Behavior

- `/api/user/scope/*` is still accepted and redirected to `/api/workspaces/me/*`.
- `/api/user/scope/*` responses include deprecation headers:
  - `Deprecation: true`
  - `Sunset: Fri, 15 May 2026 00:00:00 GMT`
  - `Link: </api/user/workspace>; rel="successor-version"`
- Portal API client now resolves personal scope URLs through `/api/user/workspace`.
- Server tracks workspace-route usage via:
  - `skyforge_workspace_route_usage_total{mode=...}`
  - `skyforge_workspace_route_rejected_total{mode=...}`

## Optional Strict Mode (for final cutover)

Set `SKYFORGE_WORKSPACE_ROUTES_STRICT=true` to reject non-personal workspace keys on legacy workspace-scoped APIs with:

- `412 Failed Precondition`
- Message: `workspace-scoped routes are deprecated; use /api/user/workspace/*`

## Migration Guidance

1. New client code must call `/api/user/workspace/...` for personal scope resources.
2. Existing `/api/workspaces/me/...` integrations should be updated during the current release window.
3. Existing `/api/user/scope/...` integrations should be updated immediately.

## Examples

- Deployments list:
  - New: `GET /api/user/workspace/deployments`
  - Old: `GET /api/workspaces/me/deployments`

- Netlab templates:
  - New: `GET /api/user/workspace/netlab/templates`
  - Old: `GET /api/workspaces/me/netlab/templates`

- Forward networks:
  - New: `GET /api/user/workspace/forward-networks`
  - Old: `GET /api/workspaces/me/forward-networks`
