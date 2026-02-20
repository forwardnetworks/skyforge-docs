# Skyforge User-Only Hard Cutover Plan

## Goal
Move Skyforge to true user-only scope. Remove workspace/project/account architecture and all backward-compatibility paths.

## Decisions
- Database strategy: data reset + clean schema.
- API strategy: remove account-scoped paths immediately (no alias layer).

## Target state
- Ownership key is username.
- No workspace/project/account context in API contracts, task contracts, or UI state.
- No account chooser/selector in portal.
- Admin paths are explicitly username-scoped.

## Workstreams

### 1) Database hard reset
- Replace project/account-scoped tables with user-scoped schema keyed by username.
- Remove `sf_projects` dependencies.
- Replace `project_id`/`account_id` ownership columns with `username` ownership columns where scope is needed.
- Recreate indexes/FKs for user-scope access patterns.

### 2) Server API hard cut
- Remove `/api/accounts/:id/...` routes.
- Introduce user-scoped canonical paths:
  - `/api/...` for authenticated user operations.
  - `/api/admin/users/:username/...` for admin operations.
- Remove account/project/workspace fields from request/response DTOs.

### 3) Task engine and worker
- Replace task ownership (`ProjectID`) with `Username`.
- Re-key queue dedupe, lock keys, and reconcile flows to username + deployment.
- Remove project/account scope terminology from task specs and metadata.

### 4) Portal
- Remove default-account resolution and account path rewriting.
- Replace all account-scoped API calls with user-scoped calls.
- Remove `accountId` state/query keys/URL params from UI flows.

### 5) Integrations/storage/governance
- Artifacts prefix becomes `artifacts/<username>/...`.
- Forward/cloud credentials are per-user only.
- Policy/governance records are user-owned.

### 6) Charts/scripts/docs
- Regenerate OpenAPI and chart swagger for user-only API.
- Update smoke/e2e scripts for user-only endpoints.
- Remove compatibility docs/mentions for workspace/project/account architecture.

### 7) Guardrails
- CI check fails if forbidden scope terms are reintroduced in source paths.
- OpenAPI schema check fails if Skyforge scope contracts include account/project/workspace IDs.

## One-shot execution order
1. Schema reset migration.
2. Server/taskengine refactor and compile.
3. Portal refactor and type-check.
4. OpenAPI/chart/docs/scripts regeneration.
5. Build/push/deploy.
6. Smoke + manual verification.

## Acceptance criteria
- No user flow requires account/project/workspace scope.
- API contracts expose only user-scoped identifiers.
- Server + portal checks pass.
- Deployed system passes smoke checks with Dex login and core workflows.

## Execution Status
- [x] Server: enforce user-only account context resolution (`self`/default account only) and block non-self account keys.
- [x] Server: remove public-viewer access mode in account RBAC helpers.
- [x] Server: raw SSE/WS account endpoints now resolve through user account context.
- [x] Portal: remove default-account discovery in HTTP client and normalize account-scoped paths to `self`.
- [x] Portal: hardcode direct WS/SSE topology + terminal endpoints to `/api/...`.
- [x] Portal: replace dynamic account path interpolation in `skyforge-api.ts` with `/api/...`.
- [x] Guardrail: reject dynamic `/api/accounts/${encodeURIComponent(...)}` paths in portal source.
- [x] API hard-cut slice: migrated deployment/lab-designer/eve user flows to canonical `/api/...` routes (server + portal).
- [x] Guardrail: reject legacy `/api/(deployments|deployments-designer|eve|containerlab/topologies)` in portal source.
- [x] Portal hard-cut slice: removed `accountId` from query-key identity tuples (cache keys now user-scope only).
- [x] API hard-cut slice: migrated remaining `account_*` endpoints (forward, variable-groups, artifacts, netlab/containerlab/terraform templates, run triggers, members/settings/delete) to `/api/...` canonical routes.
- [x] Portal hard-cut slice: rewired migrated runtime calls from `/api/...` to `/api/...` for forward/settings, artifacts, variable-groups, and template APIs.
- [x] API hard-cut slice: migrated policy reports, governance, securetrack, forward-networks, and capacity endpoints to `/api/...`.
- [x] Portal hard-cut slice: removed remaining `/api/...` API paths; runtime calls now target `/api/...`.
- [x] Portal hard-cut slice: removed `accountId` from query-key contracts and key callsites (capacity, policy reports, forward networks, deployment UI events).
- [x] Portal hard-cut slice: removed `accountId` prop contracts from topology/terminal/node-log/node-describe components (deployment-scoped only).
- [x] Portal hard-cut slice: removed legacy project-gating from policy reports, switched exports/labels to user-scope terminology, and relabeled template sources to `User repo` in deployment + designer flows.
- [x] Portal hard-cut slice: refactored lab-designer runtime state to `userScopeId` naming (kept wire-format `accountId` fields only where API/storage contracts still require them).
- [x] Portal hard-cut slice: removed hardcoded account context from capacity route query-key/enabled logic and cleaned remaining user-facing account wording (deployments, forward networks, runs, S3, docs, lab-map).
- [x] Portal hard-cut slice: removed additional route-local legacy scope naming in deployment detail/map/settings/admin views (UI labels now user-scope terminology).
- [x] API/Portal hard-cut slice: run payloads and dashboard run snapshots now emit `scopeId` (replacing run-level `accountId`), with portal run/deployment views updated to consume deploymentId/scopeId instead of accountId coupling.
- [x] API/Portal hard-cut slice: capacity summary/refresh/inventory/growth contracts now emit `scopeId` (including rollup rows and forward-network capacity responses), and OpenAPI + portal client were regenerated.
- [x] API/Portal hard-cut slice: deployment contracts now emit `scopeId` (deployment list/action/info, deployment inventory/forward/ui-events, and dashboard deployment snapshots), with portal deployment/designer consumers updated for `scopeId` + legacy fallback.
- [x] API/Portal hard-cut slice: policy report contracts now emit `scopeId` (networks + governance campaigns/assignments/exceptions), with portal API typings updated to `scopeId` canonical.
- [x] Portal hard-cut slice: designer import/draft/save/map flows now pin to local user scope and no longer rehydrate foreign legacy `accountId`/`scopeId` from persisted payloads.
- [x] Chart hard-cut slice: removed legacy workspace-compat SQL stubs (`drop/ensure legacy_workspace_id`, `project_hard_cutover`) from migrate ConfigMap/atlas manifest.
- [x] API hard-cut slice: variable-group list response no longer exposes `accountId`.
- [x] API hard-cut slice: removed legacy scope `accountId` response fields from user artifacts/templates/runs/netlab-config/designer/eve endpoints (keeping provider account identifiers where required).
- [x] Portal hard-cut slice: removed account-scoped policy-reports e2e route and accountId fallbacks in run/admin views; scope-typed client models no longer carry compatibility `accountId` fields for scope-based responses.
- [x] Portal hard-cut slice: AWS SSO settings save path now uses provider `accountId` only (no scopeId fallback).
- [x] Schema hard cut: added `20260219000100_schema_user_scope_hard_cut` migration and updated server SQL callsites to use `username` ownership columns in runtime paths.
- [x] Deploy wiring: regenerated `atlas.sum` and chart migrate ConfigMap to include `20260219000100_schema_user_scope_hard_cut` migration artifacts.
- [x] Portal hard-cut slice: removed remaining admin table `accountId` column identifier (`userId` only).
- [x] Portal hard-cut slice: renamed remaining `account*` query-key helpers/usages (`forward networks`, `EVE labs`, `templates`) to user-scoped keys and removed unused account-prefixed query-key contracts.
- [x] API/Portal hard-cut slice: governance admin contracts now use `username/usersTracked` and no longer emit `accountName` or summary `accountsTracked`.
- [x] API hard-cut slice: policy report governance audit payloads now emit `username` (removed legacy audit `accountId` field).
- [x] API hard-cut slice: admin audit events now emit `username` (removed legacy audit `accountId` response field).
- [x] Portal hard-cut slice: renamed shared deployment model from `AccountDeployment` to `UserDeployment` and updated deployment routes to consume user-scoped type names.
- [x] Portal hard-cut slice: renamed remaining project-scoped forward-network/policy-report helper names (`create/list/deleteProject*`) to user-scoped helper names (`*User*`) without behavior changes.
- [x] API hard-cut slice: canonical server scope model renamed to `UserScope` (OpenAPI now emits `skyforge.UserScope`); legacy `SkyforgeProject` retained only as deprecated alias for transition.
- [x] API hard-cut slice: server ownership context type renamed from `accountContext` to `userScopeContext` (semantic rename, no behavior change).
- [x] Runtime hard-cut slice: internal task/runtime ownership field names migrated from `ProjectID/projectID` to `Username/username` across taskstore/taskengine/taskexec/taskreconcile/tasklocks/worker reconcile paths; skyforge task access now uses `task.Username`.
- [x] API hard cut: no remaining `/api/accounts/:id/...` server routes.
- [x] Portal hard cut: remove `accountId` from UI query keys and component state contracts.
- [x] Tooling hard-cut slice: `cmd/e2echeck` and `cmd/smokecheck` now use `/api/scopes` + `/api` endpoints and user-scope wording (`scopeId` run metadata with legacy read fallback).
- [x] Portal hard-cut slice: UI E2E seed flow now provisions/list scopes via `/api/scopes` (no runtime `/api/accounts` dependency).
- [x] Portal hard-cut slice: OpenAPI operation references in `skyforge-api.ts` updated to canonical `*User*` operation IDs after schema regeneration.
- [x] API hard-cut slice: admin purge response now returns `deletedScopes` (replacing `deletedAccounts`) with portal admin settings consumer updated.
- [x] API hard-cut slice: status summary field renamed to `scopesTotal` (replacing `accountsTotal`) and count helper renamed to `countUserScopes`.
- [x] Runtime hard-cut slice: maintenance/admin naming moved from project/account language to user-scope language (`userScopeRecord`, `loadUserScopesForMaintenance`, `updateUserScopeMaintenanceFields`, `userScopeNotificationRecipients`, `getUserScopeAWSStaticCredentials`, `getUserScopeAzureCredentials`, `getUserScopeGCPCredentials`).
- [x] Runtime hard-cut slice: scope-owned credential helpers now emit `scope id is required` validation messages (removing stale internal `account id` wording in active paths).
- [x] Runtime hard-cut slice: skyforge helper/API utility naming migrated to user-scope terminology (`get/put/deleteUserScope*Credentials`, `userScopeAccessLevel*`, `findUserScopeByKey`, `syncGiteaCollaboratorsForUserScope`, `syncUserScopes`, `userScopeNotificationRecipients`).
- [x] Runtime hard-cut slice: internal sync report contract renamed to `userScopeSyncReport` with canonical `scopeId` field (replacing internal `accountId` sync report identity).
- [x] Runtime hard-cut slice: user-scope sync internals now use scope naming consistently in state variables (`scopes`, `changedScopes`, `scopeCtx`) and audit payload references (`report.scopeId`).
- [x] Runtime hard-cut slice: artifacts cleanup helper renamed to `deleteUserScopeArtifacts` (removing stale account-scoped helper naming).
- [x] Runtime hard-cut slice: store/service internals renamed from account-store terminology to user-scope-store terminology (`userScopesStore`, `pgUserScopesStore`, `newPGUserScopesStore`, `userScopeStore`).
- [x] Runtime hard-cut slice: `LabSummary` internal field renamed from `Owner` to `Creator` while preserving wire contract (`json:\"owner\"`) for API compatibility.
- [x] Config hard-cut slice: replaced runtime config section `Projects` with `UserScopeDefaults` across CUE defaults, Helm Encore config templates, config decode structs, and server/worker config consumers (`cfg.UserScopeDefaults.*`).
- [x] Runtime hard-cut slice: PG notify channel and tasknotify naming migrated from projects to user scopes (`skyforge_user_scopes_updates`, `NotifyUserScopesUpdate`, `pgNotifyUserScopesChannel`).
- [x] Runtime hard-cut slice: taskengine bootstrap dispatch naming migrated from project terminology to user-scope terminology (`TaskTypeUserScopeBootstrap`, `dispatchUserScopeBootstrapTask`).
- [x] Schema hard-cut slice: added `20260219000200_user_scope_table_rename` migration and updated active SQL callsites to canonical user-scope table names (`sf_user_scopes`, `sf_user_scope_*` credential/variable-group/server tables).
