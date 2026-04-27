# Compatibility Hard-Cut (2026-02)

This release removes runtime backward-compatibility code paths. Skyforge now uses canonical behavior only.

## Removed Runtime Compatibility

- `POST /api/integrations/forward` wrapper has been removed.
  - Use `PUT /api/integrations/forward`.
- Netlab run request no longer accepts `netlabProjectDir`.
  - Skyforge always computes the deployment directory from user scope and deployment.
- Deployment Forward network delete no longer falls back to legacy single-collector credentials.
  - Deployment config must contain `forwardCollectorId`.
- Policy Reports no longer falls back to user-scope Forward credentials.
  - Per-network Policy Reports credentials are required.
- Legacy `sf_user_forward_credentials` compatibility table has been removed.
  - Existing environments must migrate collector credentials to `sf_user_forward_collectors` before rollout.
- Legacy single-collector user endpoints have been removed:
  - `/api/forward/collector`
  - `/api/forward/collector/reset`
  - `/api/forward/collector/runtime`
  - `/api/forward/collector/logs`
  - `/api/forward/collector/restart`
- Legacy account wildcard proxy endpoint has been removed:
  - `/api/account/*rest`
  - Clients must call canonical `/api/...` routes.
- Legacy user variable-group endpoints have been removed:
  - `/api/variable-groups`
  - `/api/variable-groups/:groupID`
  - Clients must use `/api/scopes/:scopeID/variable-groups...`.
- Legacy OIDC single-flow cookie fallback has been removed.
  - OIDC callback now requires the flow state in `skyforge_oidc_flow`.
- Forward API client no longer falls back to legacy endpoint variants for:
  - SNMP credentials endpoint spelling.
  - Classic devices PUT wrapper mode.
  - Legacy collector start path.
- Secret decrypt no longer attempts empty-secret recovery key.
  - Stored secrets must match the active `SKYFORGE_SESSION_SECRET`.
- Worker queued-task DB poll fallback has been removed.
  - Queued task recovery is now handled by the canonical reconcile flow only.

## Rollout Requirements

- Validate there are no required rows left in legacy compatibility tables/code paths before deploying.
- Upgrade all clients and automation to canonical endpoints and parameters.
- Verify OIDC login and Forward integrations in staging before production rollout.
