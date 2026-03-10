# Skyforge Server + Portal Hard-Cut Migration Checklist

Last updated: 2026-03-10

## Goal

Complete the server/portal hard-cut refactor migration before any next k3d redeploy.

This checklist is the execution reference for:
- monolith reduction already in-progress
- Encore-native alignment cleanup
- path/output normalization
- commit/staging normalization

## Current Baseline

Observed in working tree:
- `components/server`: `modified=73`, `deleted=49`, `untracked=334`
- `components/portal`: `modified=44`, `deleted=5`, `untracked=227`

Build/test snapshot (2026-03-10, local):
- `components/server`: `go build ./...` passes
- `components/portal`: `make lint-portal` passes
- `components/portal`: `pnpm type-check` passes
- `components/portal`: `pnpm test --run` passes
- `components/portal`: `pnpm build` passes
- `components/server`: `go test ./internal/taskengine` still panics outside Encore runtime (`encore apps must be run using the encore command`)

Progress snapshot:
- Checklist items complete: `101`
- Checklist items remaining: `2`

## Hard-Cut Phases

## Phase 1: Frontend Output Path Hard-Cut (Do First)

- [x] Fix canonical portal build output path
  - `components/portal/vite.config.ts`
  - switch `outDir` from `../skyforge-server/frontend/frontend_dist` to `../server/frontend/frontend_dist`
- [x] Fix cleanup script path
  - `components/portal/scripts/clean-frontend-dist.mjs`
  - use `../server/frontend/frontend_dist` as canonical
- [x] Fix sync script path and remove bad-tree behavior
  - `components/portal/scripts/sync-frontend-dist.mjs`
  - canonical source: `../server/frontend/frontend_dist`
  - keep optional sync targets only when parent exists
- [x] Remove accidental generated tree if present
  - `components/skyforge-server/frontend/frontend_dist`

Success gate:
- [x] `pnpm -C components/portal build` no longer creates `components/skyforge-server/*`

## Phase 2: Server Refactor Normalization (File-Split Migration)

- [x] Stage and normalize `authn` split files
  - include new files replacing `auth_public_api.go`/`oidc_auth.go` large blocks
- [x] Stage and normalize terminal websocket split
  - plan/request/stream/connection split files under `components/server/skyforge/terminal_*`
- [x] Stage and normalize deployment split
  - `user_scope_deployment_create_update_*`
  - `user_scope_deployment_delete_cleanup_*`
- [x] Stage and normalize run-family split
  - containerlab/netlab/terraform run files
- [x] Stage and normalize policy reports/governance move
  - keep only policy-reports governance API/store surface intended for current UI
- [x] Split `cloudcredentials` private API by provider family
  - shared request/response types and crypto helpers in `components/server/cloudcredentials/private_types.go`
  - provider families in `private_aws_static_api.go`, `private_aws_sso_api.go`, `private_azure_api.go`, `private_gcp_api.go`, `private_ibm_api.go`
- [x] Split `deploymentruntime` private API by domain
  - shared request/response types in `components/server/deploymentruntime/api_types.go`
  - shared JSON/time helpers in `components/server/deploymentruntime/helpers.go`
  - runtime topology/forward state in `private_topology_forward_api.go`
  - lease state in `private_lease_api.go`
  - deployment lookup/status in `private_deployments_api.go`
- [x] Split `apitokens` private API by responsibility
  - shared request/response types in `components/server/apitokens/api_types.go`
  - token parsing/hash/header helpers in `components/server/apitokens/helpers.go`
  - DB accessors in `components/server/apitokens/store.go`
  - auth/list surface in `private_auth_api.go`
  - create/regenerate/revoke surface in `private_mutation_api.go`
- [x] Split `forwardtenant` private API by responsibility
  - shared request/response types in `components/server/forwardtenant/api_types.go`
  - runtime and credential helpers in `components/server/forwardtenant/helpers.go`
  - encrypted tenant credential store access in `components/server/forwardtenant/store.go`
  - tenant ensure orchestration in `private_ensure_api.go`
  - password rotation surface in `private_reset_api.go`
- [x] Split `internal/forwardapi` helper client by domain
  - shared models in `components/server/internal/forwardapi/types.go`
  - URL/parsing/collector-choice helpers in `components/server/internal/forwardapi/helpers.go`
  - transport/client core in `components/server/internal/forwardapi/client.go`
  - org and admin-user APIs in `components/server/internal/forwardapi/admin_org_user.go`
  - current-user password/token APIs in `components/server/internal/forwardapi/current_user_tokens.go`
  - network, collector, endpoint, and credential APIs in `components/server/internal/forwardapi/network_collectors.go`
- [x] Split `internal/maintenancejobs` by job concern
  - `components/server/internal/maintenancejobs/run.go` now owns dispatch, advisory locking, and job constants at `59` lines
  - `components/server/internal/maintenancejobs/user_sync.go` now owns user-scope/Gitea sync, audit, and notification helpers at `353` lines
  - `components/server/internal/maintenancejobs/cloud_checks.go` now owns cloud credential maintenance checks at `190` lines
  - `components/server/internal/maintenancejobs/loaders.go` now owns shared DB loaders and encrypted credential fetches at `212` lines
  - `components/server/internal/maintenancejobs/cloud_validation.go` now owns AWS/Azure/GCP validation and token helpers at `212` lines
- [x] Split `internal/taskengine/forward_client` by Forward API concern
  - `components/server/internal/taskengine/forward_client_core.go` now owns HTTP client/core models and base-url normalization at `217` lines
  - `components/server/internal/taskengine/forward_client_collectors.go` now owns network and collector lifecycle helpers at `227` lines
  - `components/server/internal/taskengine/forward_client_devices.go` now owns credential, jump-server, classic-device, and collection helpers at `247` lines
  - `components/server/internal/taskengine/forward_client_endpoints.go` now owns endpoint and endpoint-profile helpers at `138` lines
- [x] Split `internal/taskengine/forward_netlab_sync` by concern
  - `components/server/internal/taskengine/forward_sync_consts.go` now owns Forward sync keys, defaults, and option structs at `43` lines
  - `components/server/internal/taskengine/forward_netlab_catalog.go` now owns embedded netlab catalog/default helpers and Forward catalog mapping at `212` lines
  - `components/server/internal/taskengine/forward_netlab_credentials.go` now owns user Forward credential loading and credential-name sanitization at `151` lines
  - `components/server/internal/taskengine/forward_netlab_deployment_sync.go` now owns deployment network setup, collection start, and topology upload orchestration at `466` lines
- [x] Split `internal/taskengine/clabernetes_task` by concern
  - `components/server/internal/taskengine/clabernetes_task_types.go` now owns clabernetes task spec/run types and policy metadata helpers at `71` lines
  - `components/server/internal/taskengine/clabernetes_task_dispatch.go` now owns task decode and dispatch wiring at `48` lines
  - `components/server/internal/taskengine/clabernetes_task_run.go` now owns deploy/destroy execution flow at `463` lines
  - `components/server/internal/taskengine/clabernetes_topology_artifacts.go` now owns topology graph resolution, resource derivation, and artifact persistence at `138` lines
- [x] Split `internal/taskengine/clabernetes_preflight` by concern
  - `components/server/internal/taskengine/clabernetes_preflight_api.go` now owns the public preflight request/result API and deploy-fragment builder at `67` lines
  - `components/server/internal/taskengine/clabernetes_preflight_quantities.go` now owns quantity parsing, deployment request aggregation, and placement helpers at `313` lines
  - `components/server/internal/taskengine/clabernetes_preflight_compatibility.go` now owns CRD/API compatibility checks at `137` lines
  - `components/server/internal/taskengine/clabernetes_preflight_capacity.go` now owns cluster capacity checks and Kubernetes node/pod accounting at `283` lines
- [x] Split `internal/taskengine/capacity_rollup_task` by concern
  - `components/server/internal/taskengine/capacity_rollup_types.go` now owns the Forward metric payload and rollup row structs at `84` lines
  - `components/server/internal/taskengine/capacity_rollup_run.go` now owns task decode/dispatch and the top-level run orchestration at `137` lines
  - `components/server/internal/taskengine/capacity_rollup_interface.go` now owns interface rollup fetch, enrichment, and history-stat application at `239` lines
  - `components/server/internal/taskengine/capacity_rollup_device.go` now owns device rollup fetch, enrichment, and history-stat application at `213` lines
  - `components/server/internal/taskengine/capacity_rollup_store.go` now owns upsert persistence and SQL null helpers at `91` lines
  - `components/server/internal/taskengine/capacity_rollup_stats.go` now owns the shared mean/quantile/max/slope helpers at `71` lines
- [x] Compile-confirm existing `servicenow` split and fix fallout
  - confirm `components/server/servicenow/api.go` replacement files build cleanly
- [x] Split `internal/taskengine/netlab_c9s_task` by concern
  - `components/server/internal/taskengine/netlab_c9s_types.go` now owns the task payload/request models at `75` lines
  - `components/server/internal/taskengine/netlab_c9s_dispatch.go` now owns task decode/dispatch at `69` lines
  - `components/server/internal/taskengine/netlab_c9s_run.go` now owns the primary task orchestration at `388` lines
  - `components/server/internal/taskengine/netlab_c9s_manifest_resolution.go` now owns manifest resolution and runtime mapping at `132` lines
  - `components/server/internal/taskengine/netlab_c9s_topology_capture.go` now owns topology artifact capture helpers at `103` lines
- [x] Normalize `servicenow` installer split into focused files
  - `components/server/servicenow/installer_core.go` now owns installer entrypoint flow at `133` lines
  - `components/server/servicenow/installer_schema.go` now owns schema/table declarations at `249` lines
  - `components/server/servicenow/installer_forward.go` now owns Forward-specific ServiceNow records at `201` lines
  - `components/server/servicenow/installer_portal.go` now owns portal widgets/pages/navigation setup at `293` lines
  - `components/server/servicenow/installer_table_api.go` now owns table upsert/query helpers at `244` lines
- [x] Remove any stale deleted originals only after replacements are staged and compile-confirmed

Success gates:
- [x] `go build ./...` passes after each staged slice
- [x] no functional regressions from file moves (same API paths and tags where intended)
  - `./scripts/check-deployment-action-contract.sh` passes
  - `./scripts/check-deployment-action-matrix.sh` passes
  - `cd components/server && go build ./...` passes
  - `pnpm -C components/portal test --run` passes

## Phase 3: Portal IA + Monolith Cuts

- [x] Break up oversized admin settings surface
  - split `components/portal/src/routes/admin/settings.tsx` into feature-specific sections/components
- [x] Move admin settings query/mutation orchestration behind a dedicated hook
  - `components/portal/src/hooks/use-admin-settings-page.ts`
  - keep the route as a thin tab coordinator
- [x] Split admin settings tab render surfaces into focused components
  - `components/portal/src/components/admin-overview-tab.tsx`
  - `components/portal/src/components/admin-audit-tab.tsx`
  - `components/portal/src/components/admin-tasks-tab.tsx`
  - `components/portal/src/components/admin-users-tab.tsx`
  - shared props in `components/portal/src/components/admin-settings-tab-types.ts`
- [x] Split admin overview tab into focused card components
  - `components/portal/src/components/admin-overview-tab.tsx` is now a `19` line coordinator
  - `components/portal/src/components/admin-overview-auth-card.tsx` now owns authentication provider and break-glass controls at `137` lines
  - `components/portal/src/components/admin-overview-oidc-card.tsx` now owns OIDC runtime settings fields at `111` lines
  - `components/portal/src/components/admin-overview-config-card.tsx` now owns effective config rendering at `49` lines
  - `components/portal/src/components/admin-overview-impersonation-card.tsx` now owns impersonation controls at `102` lines
  - `components/portal/src/components/admin-overview-quick-deploy-card.tsx` now owns quick deploy catalog editing at `180` lines
- [x] Break up oversized user settings surface
  - move query/mutation/state into `components/portal/src/hooks/use-user-settings-page.ts`
  - keep `components/portal/src/routes/dashboard/settings.tsx` as a thin wrapper
  - split user settings sections into focused components
  - `components/portal/src/components/user-settings-cloud-credentials-card.tsx` is now a `33` line coordinator over:
    - `components/portal/src/components/user-settings-aws-static-credentials-card.tsx` at `50` lines
    - `components/portal/src/components/user-settings-aws-sso-credentials-card.tsx` at `104` lines
    - `components/portal/src/components/user-settings-azure-credentials-card.tsx` at `58` lines
    - `components/portal/src/components/user-settings-gcp-credentials-card.tsx` at `49` lines
    - `components/portal/src/components/user-settings-ibm-credentials-card.tsx` at `53` lines
- [x] Convert user settings page hook into a real coordinator over focused helper hooks
  - `components/portal/src/hooks/use-user-settings-page.ts` reduced to `25` lines
  - `components/portal/src/hooks/use-user-settings-form.ts` now owns repo normalization, schema, form state, and settings save mutation at `102` lines
  - `components/portal/src/hooks/use-user-settings-api-tokens.ts` now owns API token query/state/mutations at `105` lines
  - `components/portal/src/hooks/use-user-settings-cloud-credentials.ts` is now a `12` line coordinator over:
    - `components/portal/src/hooks/use-user-settings-aws-credentials.ts` at `249` lines
    - `components/portal/src/hooks/use-user-settings-multi-cloud-credentials.ts` at `189` lines
  - `components/portal/src/hooks/use-user-settings-byol-servers.ts` now owns BYOL server queries/state/mutations at `216` lines
- [x] Continue hard-cutting admin settings orchestration into focused hooks
  - `components/portal/src/hooks/use-admin-settings-page.tsx` reduced from `961` lines to `520` lines, and now to `178`
  - `components/portal/src/hooks/use-admin-settings-auth.tsx` now owns auth mode, OIDC settings, effective config, and quick-deploy catalog orchestration at `337` lines
  - `components/portal/src/hooks/use-admin-settings-operations.tsx` now owns impersonation, task reconciliation, and workspace cleanup flows at `155` lines
  - `components/portal/src/hooks/use-admin-settings-users-access.tsx` is now a coordinator at `84` lines
  - `components/portal/src/hooks/use-admin-settings-users-rbac.ts` now owns RBAC role query/filter/update logic at `101` lines
  - `components/portal/src/hooks/use-admin-settings-managed-users.ts` now owns managed-user create/delete flows at `98` lines
  - `components/portal/src/hooks/use-admin-settings-user-api-permissions.ts` now owns API catalog, per-user permission draft state, and save mutation logic at `169` lines
  - `components/portal/src/hooks/use-admin-settings-users-purge.ts` now owns user purge query/filter/mutation logic at `55` lines
  - `components/portal/src/hooks/admin-settings-users-access-shared.ts` now owns the shared hook arg type at `68` lines
- [x] Hard-cut root app shell into route shell plus focused layout helpers
  - `components/portal/src/routes/__root.tsx` reduced to `26` lines
  - `components/portal/src/hooks/use-root-layout.tsx` now owns session, UI config, auth/login/logout, command-menu, notifications, and breadcrumb orchestration at `278` lines
  - `components/portal/src/components/root-layout-shell.tsx` now owns the authenticated layout shell, nav chrome, footer, and login-gate integration at `271` lines
  - `components/portal/src/components/root-error-content.tsx` now owns the route-level error surface at `57` lines
  - `components/portal/src/components/root-not-found.tsx` now owns the route-level not-found surface at `32` lines
- [x] Hard-cut design system route into shell plus focused page component
  - `components/portal/src/routes/design.tsx` reduced to `6` lines
  - `components/portal/src/components/design-system-page.tsx` now owns the design-system showcase surface at `335` lines
- [x] Finalize sidebar IA hard-cut for integrations/platform/admin boundaries
  - `components/portal/src/components/side-nav.tsx`
  - keep only intended items; avoid duplicate launch points
- [x] Ensure embedded tool routing behavior is consistent
  - integrations should open in-frame through `tools.$tool` where intended
- [x] Remove obsolete routes and leftovers
  - confirm removed governance route is not referenced from nav or links
- [x] Start breaking up deployment capacity route
  - move shared capacity row types to `components/portal/src/components/capacity/deployment-capacity-types.ts`
  - move shared formatting/math/export helpers to `components/portal/src/components/capacity/deployment-capacity-utils.ts`
  - keep `components/portal/src/routes/dashboard/deployments/$deploymentId.capacity.tsx` focused on page state/render only
- [x] Extract deployment capacity state/query/computation into a dedicated hook
  - `components/portal/src/hooks/use-deployment-capacity-page.tsx`
  - route now consumes hook output instead of owning query/state/computation directly
- [x] Extract create-deployment state/query/mutation orchestration into a dedicated hook
  - `components/portal/src/hooks/use-create-deployment-page.tsx`
  - `components/portal/src/routes/dashboard/deployments/new.tsx` now owns render-only concerns
  - route reduced from `2442` lines to `1246` lines after the cut
- [x] Split create-deployment modal surfaces into focused components
  - `components/portal/src/components/deployments/import-eve-lab-dialog.tsx`
  - `components/portal/src/components/deployments/template-preview-dialog.tsx`
  - `components/portal/src/routes/dashboard/deployments/new.tsx` reduced further to `1098` lines
- [x] Split create-deployment main form surface into a focused component
  - `components/portal/src/components/deployments/create-deployment-form-card.tsx`
  - `components/portal/src/routes/dashboard/deployments/new.tsx` reduced from `1098` lines to `144` lines
- [x] Split create-deployment form card by section
  - `components/portal/src/components/deployments/create-deployment-basics-section.tsx`
  - `components/portal/src/components/deployments/create-deployment-environment-section.tsx`
  - `components/portal/src/components/deployments/create-deployment-form-card.tsx` reduced to `51` lines
- [x] Split create-deployment basics section by concern
  - `components/portal/src/components/deployments/create-deployment-config-section.tsx`
  - `components/portal/src/components/deployments/create-deployment-template-section.tsx`
  - `components/portal/src/components/deployments/create-deployment-basics-section.tsx` reduced to `16` lines
- [x] Split create-deployment template section by concern
  - `components/portal/src/components/deployments/create-deployment-template-source-section.tsx`
  - `components/portal/src/components/deployments/create-deployment-template-picker-section.tsx`
  - `components/portal/src/components/deployments/create-deployment-template-section.tsx` reduced to `14` lines
- [x] Start breaking up Forward network capacity route
  - move shared row types to `components/portal/src/components/capacity/forward-network-capacity-types.ts`
  - move shared formatting/export/stat helpers to `components/portal/src/components/capacity/forward-network-capacity-utils.ts`
  - move state/query/derivation into `components/portal/src/hooks/use-forward-network-capacity-page.tsx`
  - `components/portal/src/routes/dashboard/forward-networks/$networkRef.capacity.tsx` reduced from `4282` lines to `2863` lines
- [x] Split Forward network capacity route by tab surface
  - `components/portal/src/components/capacity/forward-network-capacity-scorecard-tab.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-interfaces-tab.tsx` is now a `22` line coordinator over:
    - `components/portal/src/components/capacity/forward-network-capacity-interface-tab-types.ts` at `5` lines
    - `components/portal/src/components/capacity/forward-network-capacity-interfaces-toolbar.tsx` at `99` lines
    - `components/portal/src/components/capacity/forward-network-capacity-interface-group-summary.tsx` at `233` lines
    - `components/portal/src/components/capacity/forward-network-capacity-interface-rollups.tsx` at `37` lines
  - `components/portal/src/components/capacity/forward-network-capacity-devices-tab.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-growth-tab.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-plan-tab.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-routing-tab.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-changes-tab.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-health-tab.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-raw-tab.tsx`
  - `components/portal/src/routes/dashboard/forward-networks/$networkRef.capacity.tsx` reduced from `2863` lines to `809` lines
  - `components/portal/src/hooks/use-forward-network-capacity-page.tsx` is now the primary state/query/computation owner at `1438` lines
- [x] Split Forward network capacity route dialog family
  - `components/portal/src/components/capacity/forward-network-capacity-interface-trend-dialog.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-device-trend-dialog.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-pick-interface-dialog.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-pick-device-dialog.tsx`
  - `components/portal/src/components/capacity/forward-network-capacity-tcam-evidence-dialog.tsx`
  - `components/portal/src/routes/dashboard/forward-networks/$networkRef.capacity.tsx` reduced from `809` lines to `365` lines
- [x] Split Forward network capacity hook into coordinator vs derived model
  - `components/portal/src/hooks/use-forward-network-capacity-page.tsx` reduced from `1438` lines to `366` lines
  - `components/portal/src/hooks/use-forward-network-capacity-derived.tsx` now owns the derived rollup rows, summaries, history/growth queries, table columns, and routing summaries at `1167` lines
- [x] Split Forward network capacity derived model by concern
  - `components/portal/src/hooks/use-forward-network-capacity-derived.tsx` reduced from `1167` lines to `18` lines
  - `components/portal/src/hooks/use-forward-network-capacity-rollups.tsx` now owns rollup rows, group summaries, overview, and table columns at `678` lines
  - `components/portal/src/hooks/use-forward-network-capacity-history-growth.tsx` reduced from `295` lines to `15` lines
  - `components/portal/src/hooks/use-forward-network-capacity-history.tsx` now owns history queries, chart points, and computed stats at `144` lines
  - `components/portal/src/hooks/use-forward-network-capacity-growth.tsx` now owns growth queries and growth row derivation at `168` lines
  - `components/portal/src/hooks/use-forward-network-capacity-routing.tsx` now owns routing filters and VRF summary derivation at `168` lines
  - `components/portal/src/hooks/forward-network-capacity-derived-types.ts` holds the shared derived-hook input contract at `41` lines
- [x] Split Forward network capacity rollup model by concern
  - `components/portal/src/hooks/use-forward-network-capacity-rollups.tsx` reduced from `678` lines to `27` lines
  - `components/portal/src/hooks/use-forward-network-capacity-rollup-rows.tsx` now owns interface/device row derivation at `193` lines
  - `components/portal/src/hooks/use-forward-network-capacity-rollup-summaries.tsx` now owns group summaries and overview at `173` lines
  - `components/portal/src/hooks/use-forward-network-capacity-rollup-columns.tsx` reduced from `343` lines to `21` lines
  - `components/portal/src/hooks/use-forward-network-capacity-interface-columns.tsx` now owns interface table column definitions at `258` lines
  - `components/portal/src/hooks/use-forward-network-capacity-device-columns.tsx` now owns device table column definitions at `92` lines
- [x] Hard-cut the labs designer route into a thin shell
  - `components/portal/src/routes/dashboard/labs/designer.tsx` reduced from `2425` lines to `18` lines
  - `components/portal/src/components/lab-designer-page.tsx` now owns the current designer UI/state surface at `2414` lines
- [x] Split labs designer page by primary render boundary
  - `components/portal/src/components/lab-designer-page.tsx` reduced from `2414` lines to `1246` lines
  - `components/portal/src/components/lab-designer-workspace.tsx` initially owned the canvas, palette, and context-menu surface at `649` lines and is now reduced to `55`
  - `components/portal/src/components/lab-designer-palette-panel.tsx` now owns the palette search/filter/catalog surface at `134` lines
  - `components/portal/src/components/lab-designer-canvas-surface.tsx` is now a `167` line coordinator over:
    - `components/portal/src/components/lab-designer-node-menu.tsx` at `192` lines
    - `components/portal/src/components/lab-designer-edge-menu.tsx` at `74` lines
    - `components/portal/src/components/lab-designer-canvas-menu.tsx` at `70` lines
  - `components/portal/src/components/lab-designer-workspace-types.ts` now owns the shared workspace prop contract at `64` lines
  - `components/portal/src/components/lab-designer-sidebar.tsx` now owns the lab/node/YAML right rail at `340` lines
  - `components/portal/src/components/lab-designer-import-dialog.tsx` now owns the template import flow at `138` lines
  - `components/portal/src/components/lab-designer-quickstart-dialog.tsx` now owns the CLOS quickstart flow at `135` lines
  - shared palette helpers moved to `components/portal/src/components/lab-designer-palette.tsx` at `208` lines
  - shared node renderer moved to `components/portal/src/components/lab-designer-node.tsx` at `48` lines
  - shared designer types moved to `components/portal/src/components/lab-designer-types.ts` at `59` lines
- [x] Split labs designer page into shell vs orchestration hook
  - `components/portal/src/components/lab-designer-page.tsx` reduced from `1246` lines to `257` lines
  - `components/portal/src/hooks/use-lab-designer-page.tsx` now owns the designer state, queries, mutations, drag/drop, import, draft, and deploy orchestration at `1115` lines
- [x] Split labs designer orchestration hook by concern
  - `components/portal/src/hooks/use-lab-designer-page.tsx` reduced from `1115` lines to `379` lines
  - `components/portal/src/hooks/use-lab-designer-actions.tsx` now owns topology editor actions, draft persistence, drag/drop, map open, and import synchronization at `561` lines
  - `components/portal/src/hooks/use-lab-designer-data.tsx` now owns query and mutation flows for users, registry, templates, and deploy/save/import operations at `253` lines
  - `components/portal/src/hooks/use-lab-designer-derived.tsx` now owns YAML/template derivation, palette filtering, and option shaping at `175` lines
  - `components/portal/src/hooks/lab-designer-utils.ts` now owns shared URL/tag helper functions at `38` lines
  - `components/portal/src/components/lab-designer-page.tsx` is now `272` lines after wiring the new hook-family split
- [x] Split labs designer action hook by concern
  - `components/portal/src/hooks/use-lab-designer-actions.tsx` is now a `12` line coordinator
  - `components/portal/src/hooks/lab-designer-actions-types.ts` now owns the shared action hook input contract at `57` lines
  - `components/portal/src/hooks/use-lab-designer-topology-actions.tsx` now owns quickstart, layout, rename, and delete/menu flows at `266` lines
  - `components/portal/src/hooks/use-lab-designer-persistence-actions.tsx` now owns draft, import-sync, export, and map launch flows at `199` lines
  - `components/portal/src/hooks/use-lab-designer-dnd-actions.tsx` now owns drag/drop palette insertion and image-tag resolution at `81` lines
- [x] Continue hard-cutting deployment capacity route by moving shell-only surfaces out of the route
  - `components/portal/src/routes/dashboard/deployments/$deploymentId.capacity.tsx` reduced from `2117` lines to `1523` lines
  - `components/portal/src/components/capacity/deployment-capacity-header.tsx` now owns the page header and top-level filter/action controls at `149` lines
  - `components/portal/src/components/capacity/deployment-capacity-summary-cards.tsx` now owns the summary/status card strip at `65` lines
  - `components/portal/src/components/capacity/deployment-capacity-dialogs.tsx` is now a `20` line coordinator over:
    - `components/portal/src/components/capacity/deployment-capacity-interface-trend-dialog.tsx` at `226` lines
    - `components/portal/src/components/capacity/deployment-capacity-device-trend-dialog.tsx` at `76` lines
    - `components/portal/src/components/capacity/deployment-capacity-pick-interface-dialog.tsx` at `104` lines
    - `components/portal/src/components/capacity/deployment-capacity-pick-device-dialog.tsx` at `98` lines
    - `components/portal/src/components/capacity/deployment-capacity-tcam-evidence-dialog.tsx` at `29` lines
- [x] Split deployment capacity tab surfaces into focused components
  - `components/portal/src/components/capacity/deployment-capacity-tabs.tsx` is now a `49` line coordinator
  - `components/portal/src/components/capacity/deployment-capacity-interfaces-tab.tsx` is now a `44` line coordinator over:
    - `components/portal/src/components/capacity/deployment-capacity-interface-tab-types.ts` at `6` lines
    - `components/portal/src/components/capacity/deployment-capacity-interfaces-toolbar.tsx` at `118` lines
    - `components/portal/src/components/capacity/deployment-capacity-interface-group-summary.tsx` at `48` lines
    - `components/portal/src/components/capacity/deployment-capacity-interface-group-columns.tsx` at `184` lines
  - `components/portal/src/components/capacity/deployment-capacity-devices-tab.tsx` now owns the devices tab at `185` lines
  - `components/portal/src/components/capacity/deployment-capacity-growth-tab.tsx` now owns the growth tab at `355` lines
  - `components/portal/src/components/capacity/deployment-capacity-routing-tab.tsx` is now an `18` line coordinator over:
    - `components/portal/src/components/capacity/deployment-capacity-vrf-summary-card.tsx` at `116` lines
    - `components/portal/src/components/capacity/deployment-capacity-tcam-card.tsx` at `143` lines
    - `components/portal/src/components/capacity/deployment-capacity-route-scale-card.tsx` at `129` lines
    - `components/portal/src/components/capacity/deployment-capacity-bgp-neighbors-card.tsx` at `98` lines
  - `components/portal/src/components/capacity/deployment-capacity-health-tab.tsx` now owns the health tab at `39` lines
  - `components/portal/src/components/capacity/deployment-capacity-raw-tab.tsx` now owns the raw-data tab at `56` lines
- [x] Split deployment capacity page hook into coordinator vs derived hook
  - `components/portal/src/hooks/use-deployment-capacity-page.tsx` reduced from `1321` lines to `622` lines, and now to `261`
  - `components/portal/src/hooks/use-deployment-capacity-derived.tsx` is now a thin coordinator at `16` lines
  - `components/portal/src/hooks/use-deployment-capacity-rollups.tsx` is now a `46` line coordinator over:
    - `components/portal/src/hooks/use-deployment-capacity-grouping-options.tsx` at `39` lines
    - `components/portal/src/hooks/use-deployment-capacity-interface-rows.tsx` at `106` lines
    - `components/portal/src/hooks/use-deployment-capacity-device-rows.tsx` at `88` lines
    - `components/portal/src/hooks/use-deployment-capacity-group-summaries.tsx` at `204` lines
    - `components/portal/src/hooks/use-deployment-capacity-overview.tsx` at `19` lines
  - derived concerns now live under:
    - `components/portal/src/hooks/use-deployment-capacity-history.tsx`
    - `components/portal/src/hooks/use-deployment-capacity-growth.tsx`
    - `components/portal/src/hooks/use-deployment-capacity-routing.tsx`
    - `components/portal/src/hooks/use-deployment-capacity-columns.tsx`
- [x] Convert create-deployment page hook into a real coordinator over focused helper hooks
  - `components/portal/src/hooks/use-create-deployment-page.tsx` reduced from `1111` lines to `211` lines
  - `components/portal/src/hooks/use-create-deployment-data.tsx` reduced from `680` lines to `81` lines
  - `components/portal/src/hooks/use-create-deployment-settings.tsx` now owns scope/session/lifetime/default-name wiring at `248` lines
  - `components/portal/src/hooks/use-create-deployment-template-catalog.tsx` now owns template/import/catalog/collector query wiring at `449` lines
  - `components/portal/src/hooks/use-create-deployment-import-options.tsx` owns BYOS/EVE server and import-option query/state derivation
  - `components/portal/src/hooks/use-create-deployment-mutations.tsx` is now a `15` line coordinator over:
    - `components/portal/src/hooks/use-create-deployment-mutations-types.ts` at `26` lines
    - `components/portal/src/hooks/use-create-deployment-create-mutation.tsx` at `213` lines
    - `components/portal/src/hooks/use-create-deployment-import-mutations.tsx` at `106` lines
    - `components/portal/src/hooks/use-create-deployment-validate-mutation.tsx` at `69` lines
- [x] Hard-cut deployment detail route into shell plus focused page hook/components
  - `components/portal/src/routes/dashboard/deployments/$deploymentId.index.tsx` reduced to `130` lines
  - `components/portal/src/hooks/use-deployment-detail-page.tsx` reduced from `555` lines to `289` lines
  - `components/portal/src/hooks/use-deployment-detail-data.tsx` now owns deployment detail query/state/derived wiring at `200` lines
  - `components/portal/src/hooks/deployment-detail-utils.ts` now owns shared status/resource-estimate helpers at `98` lines
  - focused render surfaces moved to:
    - `components/portal/src/components/deployments/deployment-detail-header.tsx`
    - `components/portal/src/components/deployments/deployment-detail-topology-tab.tsx`
    - `components/portal/src/components/deployments/deployment-detail-logs-tab.tsx`
    - `components/portal/src/components/deployments/deployment-detail-config-tab.tsx`
    - `components/portal/src/components/deployments/deployment-detail-delete-dialog.tsx`
    - `components/portal/src/components/deployments/deployment-detail-standalone-view.tsx`
    - `components/portal/src/components/deployments/deployment-run-output.tsx`
    - `components/portal/src/components/deployments/deployment-status-badge.tsx`
- [x] Hard-cut run detail route into shell plus focused page hook/components
  - `components/portal/src/routes/dashboard/runs/$runId.tsx` reduced to `14` lines
  - `components/portal/src/hooks/use-run-detail-page.ts` now owns run snapshot, log/lifecycle state, cancel/clear actions, and provenance derivation at `268` lines
  - `components/portal/src/components/runs/run-detail-page-content.tsx` now owns the run detail render surface at `281` lines
- [x] Hard-cut Forward collectors route into shell plus focused page hook/component
  - `components/portal/src/routes/dashboard/forward.collectors.tsx` reduced to `12` lines
  - `components/portal/src/hooks/use-forward-collectors-page.tsx` now owns collector query/state/mutation orchestration at `290` lines
  - `components/portal/src/components/forward-collectors-page-content.tsx` is now a `26` line coordinator over:
    - `components/portal/src/components/forward-collectors-create-card.tsx` at `124` lines
    - `components/portal/src/components/forward-collectors-list-card.tsx` at `101` lines
- [x] Hard-cut Forward credentials route into shell plus focused page hook/component
  - `components/portal/src/routes/dashboard/forward.credentials.tsx` reduced to `12` lines
  - `components/portal/src/hooks/use-forward-credentials-page.tsx` now owns managed credential query/reset, collector credential CRUD, and local form state at `146` lines
  - `components/portal/src/components/forward-credentials-page-content.tsx` now owns the managed-credential, add-credential, and saved-credential render surface at `255` lines
- [x] Hard-cut notifications route into shell plus focused page hook/component
  - `components/portal/src/routes/notifications.tsx` reduced to `12` lines
  - `components/portal/src/hooks/use-notifications-page.tsx` now owns notifications query/state/selection/delete/read orchestration at `176` lines
  - `components/portal/src/components/notifications-page-content.tsx` now owns the notifications table, bulk-action bar, and delete dialog render surface at `278` lines
- [x] Hard-cut S3 route into shell plus focused page component
  - `components/portal/src/routes/dashboard/s3.tsx` reduced to `6` lines
  - `components/portal/src/components/s3-page.tsx` now owns the object-store browser render surface at `336` lines
- [x] Hard-cut Forward network index route into shell plus focused page hook/component
  - `components/portal/src/routes/dashboard/forward-networks/index.tsx` reduced to `29` lines
  - `components/portal/src/hooks/use-forward-networks-page.tsx` now owns scope selection, network CRUD, and portfolio query orchestration at `177` lines
  - `components/portal/src/components/forward-networks-page-content.tsx` now owns the saved-network, add-network, and portfolio render surface at `312` lines
- [x] Hard-cut ServiceNow route into shell plus focused page hook/component
  - `components/portal/src/routes/dashboard/servicenow.tsx` reduced to `12` lines
  - `components/portal/src/hooks/use-servicenow-page.tsx` now owns install/config/status orchestration at `229` lines
  - `components/portal/src/components/servicenow-page-content.tsx` now owns the ServiceNow setup/status render surface at `286` lines
- [x] Hard-cut deployments list route into shell plus focused page hook/components
  - `components/portal/src/routes/dashboard/deployments/index.tsx` reduced to `29` lines
  - `components/portal/src/hooks/use-deployments-page.tsx` is now a coordinator at `83` lines
  - `components/portal/src/hooks/use-deployments-page-data.tsx` now owns deployments list query/filter/scope/auth-mode orchestration at `203` lines
  - `components/portal/src/hooks/use-deployments-page-actions.tsx` now owns start/stop/destroy/lifetime/login actions at `267` lines
  - `components/portal/src/hooks/deployments-page-utils.ts` now owns deployment formatting/filtering/status helpers at `231` lines
  - `components/portal/src/components/deployments/deployments-page-content.tsx` now owns the primary list render surface at `335` lines
  - side surfaces moved to:
    - `components/portal/src/components/deployments/deployments-activity-feed.tsx`
    - `components/portal/src/components/deployments/deployments-lifetime-dialog.tsx`
    - `components/portal/src/components/deployments/deployments-delete-dialog.tsx`
  - shared status rendering now reuses `components/portal/src/components/deployments/deployment-status-badge.tsx` with `xs` support instead of a route-local badge helper
- [x] Continue hard-cutting topology viewer by extracting reusable node/util/body surfaces
  - `components/portal/src/components/topology-viewer.tsx` remains a thin wrapper over `TopologyViewerSurface`
  - `components/portal/src/components/topology-viewer-surface.tsx` is now a `76` line coordinator over the topology viewer shell
  - `components/portal/src/hooks/use-topology-viewer-surface.tsx` now owns topology viewer state, hover/menu/modal wiring, and menu/modal callback orchestration at `361` lines
  - `components/portal/src/hooks/use-topology-viewer-canvas-controls.tsx` now owns zoom, fit-view, and graph reset controls at `131` lines
  - `components/portal/src/hooks/use-topology-viewer-node-edge-actions.tsx` now owns node/edge click, hover, and selection action wiring at `257` lines
  - `components/portal/src/components/topology-viewer-canvas.tsx` now owns the ReactFlow canvas shell and tool-strip wiring at `78` lines
  - `components/portal/src/components/topology-viewer-dialogs.tsx` is now a `16` line coordinator over:
    - `components/portal/src/components/topology-viewer-dialog-types.ts` at `64` lines
    - `components/portal/src/components/topology-viewer-interfaces-dialog.tsx` at `38` lines
    - `components/portal/src/components/topology-viewer-running-config-dialog.tsx` at `37` lines
    - `components/portal/src/components/topology-viewer-capture-dialog.tsx` at `115` lines
    - `components/portal/src/components/topology-viewer-impairment-dialog.tsx` at `164` lines
  - `components/portal/src/components/topology-viewer-menus.tsx` now owns the node and edge menu coordinator surface at `59` lines
  - `components/portal/src/components/topology-viewer-modals.tsx` now owns the terminal/logs/describe/dialog modal coordinator at `97` lines
  - `components/portal/src/components/topology-viewer-node-menu.tsx` now owns the node context-menu surface at `171` lines
  - `components/portal/src/components/topology-viewer-edge-menu.tsx` now owns the edge context-menu surface at `93` lines
  - `components/portal/src/components/topology-viewer-custom-node.tsx` now owns the custom node renderer and node-types export at `150` lines
  - `components/portal/src/components/topology-viewer-utils.ts` now owns edge decoration, stats formatting, and layout/highlight helpers at `146` lines
  - `components/portal/src/components/topology-viewer-bodies.tsx` now owns the interfaces and running-config dialog bodies at `125` lines
  - `components/portal/src/components/topology-viewer-panels.tsx` now owns the tools panel, live-stats overlay, and recent-activity panel
  - `components/portal/src/hooks/use-topology-viewer-graph.tsx` now owns topology node/edge derivation from deployment topology input at `90` lines
  - `components/portal/src/hooks/use-topology-viewer-interactions.tsx` now owns topology mutations, downloads, context-menu callbacks, and impairment application at `280` lines
  - `components/portal/src/hooks/use-topology-viewer-effects.tsx` now owns persisted-position, deep-link, layout/highlight, and stats-refresh effects at `363` lines
  - `components/portal/src/hooks/use-topology-viewer-activity.tsx` now owns the recent-activity query and edge-flag derivation at `37` lines
- [x] Split admin users tab by card boundary
  - `components/portal/src/components/admin-users-tab.tsx` reduced to `17` lines
  - `components/portal/src/components/admin-users-management-card.tsx` now owns managed-user create/delete flows at `118` lines
  - `components/portal/src/components/admin-users-rbac-card.tsx` now owns RBAC assignment and effective-role rendering at `177` lines
  - `components/portal/src/components/admin-users-api-permissions-card.tsx` now owns per-user API permission override rendering at `156` lines
  - `components/portal/src/components/admin-users-purge-card.tsx` now owns the dev-only purge surface at `70` lines
- [x] Hard-cut root app shell into route shell plus focused layout components/hooks
  - `components/portal/src/routes/__root.tsx` reduced to `26` lines
  - `components/portal/src/hooks/use-root-layout.tsx` now owns auth/session/layout orchestration
  - `components/portal/src/components/root-layout-shell.tsx` now owns the app-shell render surface
  - focused helpers moved to:
    - `components/portal/src/components/root-login-gate.tsx`
    - `components/portal/src/components/root-breadcrumbs.tsx`
    - `components/portal/src/components/root-error-content.tsx`
    - `components/portal/src/components/root-not-found.tsx`
- [x] Hard-cut ServiceNow route into shell plus focused page hook/component
  - `components/portal/src/routes/dashboard/servicenow.tsx` now owns route wiring only
  - `components/portal/src/hooks/use-servicenow-page.tsx` now owns ServiceNow config/setup/status query and mutation orchestration
  - `components/portal/src/components/servicenow-page-content.tsx` now owns the ServiceNow render surface
- [x] Hard-cut Forward networks index route into shell plus focused page hook/component
  - `components/portal/src/routes/dashboard/forward-networks/index.tsx` now owns route wiring only
  - `components/portal/src/hooks/use-forward-networks-page.tsx` now owns scope/network/portfolio query and mutation orchestration
  - `components/portal/src/components/forward-networks-page-content.tsx` now owns the Forward networks index render surface
- [x] Split admin users tab by card boundary
  - `components/portal/src/components/admin-users-tab.tsx` is now a thin coordinator
  - focused card surfaces moved to:
    - `components/portal/src/components/admin-users-management-card.tsx`
    - `components/portal/src/components/admin-users-rbac-card.tsx`
    - `components/portal/src/components/admin-users-api-permissions-card.tsx`
    - `components/portal/src/components/admin-users-purge-card.tsx`
- [x] Hard-cut quick deploy route into shell plus focused page hook/component
  - `components/portal/src/routes/dashboard/deployments/quick.tsx` reduced to `12` lines
  - `components/portal/src/hooks/use-quick-deploy-page.tsx` now owns catalog, lease policy, preview, deploy, and Forward-sync orchestration at `265` lines
  - `components/portal/src/components/quick-deploy-page-content.tsx` now owns the quick deploy lease/card/preview render surface at `166` lines
- [x] Hard-cut Forward credentials route into shell plus focused page hook/component
  - `components/portal/src/routes/dashboard/forward.credentials.tsx` reduced to `12` lines
  - `components/portal/src/hooks/use-forward-credentials-page.tsx` now owns tenant credential, custom credential-set, and delete/reset orchestration at `146` lines
  - `components/portal/src/components/forward-credentials-page-content.tsx` now owns the managed-credential, add-credential, and saved-credential render surface at `255` lines

Success gates:
- [x] `make lint-portal` passes
- [x] `pnpm -C components/portal type-check` passes
- [x] `pnpm -C components/portal test --run` passes
- [x] `pnpm -C components/portal build` passes
- [x] `cd components/server && go build ./...` passes
- [x] targeted `go test` only where runnable outside `encore run`
  - Runnable package set (outside Encore runtime) passes:
    - `cd components/server && go test -count=1 ./internal/authbrowser ./internal/awsssostore ./internal/clabnative ./internal/deploycore ./internal/skyforgeconfig ./internal/skyforgecore ./internal/smokecheckutil ./internal/taskexec ./internal/terminalutil ./worker/taskrunner`
  - Known Encore-runtime-only package set (expected panic with plain `go test`):
    - `./authn ./internal/taskdispatch ./internal/taskengine ./skyforge ./worker`
- [x] side-nav tests explicitly cover final hierarchy

## Phase 4: API Artifact Regeneration + Consistency

- [x] Regenerate/refresh server OpenAPI artifact if endpoint shapes changed
  - `components/server/skyforge/openapi.json`
- [x] Regenerate portal client artifacts from OpenAPI
  - `components/portal/src/lib/openapi.gen.ts`
  - `components/portal/src/lib/api-client.ts`
- [x] Update route tree artifact when route layout changes
  - `components/portal/src/routeTree.gen.ts`

Success gate:
- [x] generated artifacts and source changes are consistent in same working slice
  - `./scripts/check-generated-drift.sh` passes (OpenAPI + portal OpenAPI types + infra configs + netlab drift + c9s contract)

## Phase 5: Final Pre-Deploy Gate (No Redeploy Yet)

- [x] Re-enable CI triggers and explicit portal lint gate
  - `.github/workflows/ci.yml` restored to `push`, `pull_request`, and `workflow_dispatch`
  - CI now runs `make lint-portal` before the broader test flow
- [x] Add a local lint entrypoint matching CI
  - `Makefile` now exposes `lint-portal`
- [x] Portal lint and type-check are green again
  - `make lint-portal`
  - `pnpm -C components/portal type-check`
- [x] `go build ./...` in `components/server`
- [x] `pnpm test --run` in `components/portal`
- [x] `pnpm build` in `components/portal`
- [x] `git status --short` reviewed for expected changes only
- [x] no accidental build outputs outside canonical paths

## Commit Strategy (Required)

- [ ] Commit in focused slices, not one giant commit
  1. portal path hard-cut
  2. server split normalization batches
  3. portal IA/admin split
  4. generated artifacts refresh
  5. docs/update pass
- [ ] Each commit must build at least the affected component

## Do-Not-Do Until Checklist Complete

- [x] Do not delete/recreate k3d cluster
- [x] Do not run redeploy workflows
- [x] Do not mix deployment-script edits into refactor commits unless directly required for compile/test

## Validation Commands

```bash
# server
cd components/server
go build ./...

# portal
cd ../portal
pnpm test --run
pnpm build

# status snapshot
cd /home/captainpacket/src/skyforge
git -C components/server status --short | sed -n '1,200p'
git -C components/portal status --short | sed -n '1,200p'
```
