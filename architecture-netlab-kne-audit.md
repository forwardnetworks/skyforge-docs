# Netlab/Clabernetes Architecture Audit (Encore-Native)

Date: 2026-02-25

## Scope

- Server API (`components/server/skyforge`)
- Worker/task engine (`components/server/internal/taskengine`)
- Portal action clients (`components/portal/src/lib`, deployments routes)
- Helm typed config rendering (`components/charts/skyforge/templates`)
- Manual validation workflows (automated E2E harness retired)

## Baseline Findings

- Deployment action contract was split across `/action` and wrapper endpoints (`/start`, `/stop`, `/destroy`).
- Clabernetes naming primitives were duplicated across server and taskengine and could drift.
- Runtime image defaults were duplicated in taskengine constants and config/chart values.
- C9s docs still referenced older namespace/mode behavior.

## Hard-Cut Decisions Applied

- Canonical deployment action endpoint: `POST /api/users/:id/deployments/:deploymentID/action`.
- Remove wrapper API handlers from server surface (`/start`, `/stop`, `/destroy`).
- Keep native-only C9s behavior; no BYOS-mode fallback in `c9s/netlab`.
- Require configured netlab generator/applier images at runtime; no taskengine hardcoded fallback images.

## Implemented Changes

- Added shared naming package:
  - `components/server/internal/clabnative/naming.go`
  - `UserScopeNamespace(...)`
  - `TopologyName(...)` with deterministic 40-char cap + hash suffix.
- Updated server and taskengine to consume shared naming helpers.
- Migrated first-party callers to `/action`:
  - portal API helper now routes start/stop/destroy through `/action`
- Regenerated OpenAPI and portal typed client:
  - `components/server/skyforge/openapi.json`
  - `components/charts/skyforge/files/openapi.json`
  - `components/portal/src/lib/openapi.gen.ts`
- Updated chart config rendering to require netlab image settings for typed Encore config.
- Updated docs to reflect current namespace and native-mode behavior.
- Consolidated Kubernetes helper logic into `internal/kubeutil` and reduced
  `internal/taskengine/clabernetes_kube.go` to thin wrappers to prevent helper drift.

## Verification Gates

- `encore test ./skyforge`
- `go test ./internal/clabnative`
- `pnpm -s biome check` on touched portal files
- `pnpm -s type-check`
- `helm lint components/charts/skyforge`
- `./scripts/check-deployment-action-contract.sh`
- `SKYFORGE_SMOKE_SCOPE=deploy-forward ./scripts/post-deploy-smoke.sh` validates deployment action usage (`/action` + `/preflight`) plus Forward sync checks through server-native smokecheck

## Residual Follow-ups (Non-blocking)

- Add metric counters by action `reason` (`queued`, `already_present`, `in_flight_duplicate`, etc.) for dashboards.
