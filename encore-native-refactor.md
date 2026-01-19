# Encore-native refactor notes (Skyforge)

This document captures the remaining “Encore-native alignment” work that is **not** implemented yet,
and what it would take to do it cleanly without regressing the current working system.

Status: the system uses a dedicated worker **Deployment** to drain the task queue.

Note: API/worker image separation is now done using `encore build docker --services=...`:
- API image excludes the `worker` service.
- Worker image includes the `worker` service.
We still keep the infra config split so only the worker pod has `subscriptions` in the runtime infra config.

Note: Encore requires `pubsub.NewSubscription(...)` calls to be made from package-level variables
with a **string literal** subscription name and a constant `MaxConcurrency`. That means we cannot
conditionally register a subscription (or switch its concurrency) based on environment variables.

## 1) True service split (no build tags)

Goal:
- API pods run **only** API endpoints (no PubSub subscription code linked in).
- Worker pods run **only** the task consumer + execution engine.
- Use `encore build docker --services=...` to build two images.

### Why it’s non-trivial today
Task execution currently lives inside the `encore.app/skyforge` service package and depends on many
non-API helpers in that package. In Encore, one service cannot import another service’s internal
implementation code as a library.

### Clean approach
1. Extract task execution “engine” into a **non-service** library package, e.g.:
   - `server/internal/taskengine`
   - `server/internal/skyforgecore`
2. The library package owns:
   - DB task store helpers (read task, mark running/finished, append logs/events, advisory locks).
   - Dispatch logic (`labpp`, `netlab`, `terraform`, `clabernetes`, etc).
   - Any shared integration helpers needed by both API + worker.
3. Create new service `server/taskworker` with:
   - `//encore:service`
   - PubSub subscription handler.
   - Calls into `internal/taskengine` to process the task.
4. Keep `server/skyforge` as the API service:
   - Creates tasks and publishes queue events.
   - Reads task state/logs/events for the UI.
   - Does **not** register the subscription.

### Image build
- API image (no worker subscriptions):
  - `encore build docker ... --services=skyforge,health,storage`
- Worker image (task/maintenance subscriptions):
  - `encore build docker ... --services=skyforge,health,storage,worker`

### Helm
- Worker deployment uses the worker image.
- API deployment uses the API image.

## 2) Typed config via Encore config (CUE / runtime config)

Goal:
- Replace ad-hoc `os.Getenv` parsing with typed config backed by Encore config.
- Reduce drift between Helm values and runtime behavior.

### Practical migration plan (incremental)
1. Start with a small typed config surface that is safe to move first (task runner, timeouts, toggles).
2. Add `config.cue` to each service that needs typed config (at least `skyforge`, `taskworker`).
3. Drive values from:
   - `ENCORE_RUNTIME_CONFIG` secret (already wired in deployments) OR
   - Build-time CUE defaults for dev.
4. Move one config “domain” at a time:
   - tasks/worker knobs
   - gitea/netbox/nautobot URLs
   - LDAP/OIDC
- netlab/labpp runner settings

### Current progress
- `server/skyforge/config.cue` provides defaults for a few safe knobs (worker enabled default,
  notification/check intervals, EVE running-scan limits).
- Configuration is sourced from typed Encore config (`ENCORE_CFG_*`) plus Encore secrets, with only
  a few remaining env reads for non-functional metadata (for example build/version info).

### Helm changes required
- Render the `ENCORE_RUNTIME_CONFIG` secret from Helm values (or manage it out-of-band) so the
  cluster deployment does not depend on environment-variable parsing.
  - Chart support exists but is disabled by default: `charts/skyforge/values.yaml` (`skyforge.encoreRuntimeConfig`).

## 3) Logging

Status:
- Task queue publishing and task-runner “error prints” now use `encore.dev/rlog` for better
  correlation in Encore traces.
- Large parts of the codebase still use `log.Printf`; we can continue migrating opportunistically.

## 4) Cron

Status:
- The system relies on Encore Cron jobs for periodic maintenance:
  - Republishing queued task events (reconcile queue).
  - Marking stuck running tasks as failed (reconcile running).
  - Workspace sync and cloud credential checks (published to the maintenance PubSub topic).
  - Task queue metrics refresh.
- Legacy Kubernetes CronJobs have been removed from the Helm chart. Self-hosted setups must ensure Encore cron jobs are running, or provide an external scheduler that triggers the private cron endpoints.

Operational note:
- Skyforge no longer runs “cron fallback loops” inside the worker. This keeps the system aligned with Encore’s cron model and avoids surprising background work.

## 5) Task queue metrics

Status:
- The task runner already records queue latency and run duration metrics.
- Dedicated worker pods also run a background loop to refresh current-depth gauges:
  - `skyforge_tasks_queued_current_total`, `skyforge_tasks_running_current_total`
  - `skyforge_tasks_queued_oldest_age_seconds_total`
  - Per-task-type: `skyforge_tasks_queued_current`, `skyforge_tasks_running_current`, `skyforge_tasks_queued_oldest_age_seconds`

## Remaining TODOs (post-demo)

These are the next “Encore-native” cleanups that improve multi-replica correctness and reduce legacy surface area.

### A) Worker-owned cancellation
Status: implemented
- API publishes `skyforge-task-cancel` events (and marks tasks canceled in DB).
- Worker consumes cancel events and performs provider-specific cleanup via `internal/taskengine`.

### B) Remove legacy internal dispatch endpoints
Status: implemented
- Task execution lives in `server/internal/taskengine` and is invoked by the worker.
- The API surface is enqueue + query state/logs + admin/maintenance.

### C) Topology graph parity
Status:
- `netlab-c9s-run` now stores a post-deploy topology artifact (derived from clabernetes pods) for correct mgmt IP rendering.
- `clabernetes-run` now stores a post-deploy topology artifact (derived from clabernetes pods) for correct mgmt IP rendering.

TODO:
- None (parity is now implemented for clabernetes-backed deployments).

### D) Typed config consolidation
Goal:
- Move remaining “knob” configuration into Encore typed config (`ENCORE_CFG_*`) and Encore secrets.
- Keep `ENCORE_RUNTIME_CONFIG` reserved for infrastructure/runtime settings (subscriptions, etc).
- Keep the Helm chart as the single deploy-time configuration surface.

Status:
- Most runtime knobs are already read via typed Encore config (`config.Load`) + Encore secrets.
- Remaining env reads are limited to pod identity (`POD_NAME`, `POD_NAMESPACE`) and build metadata.

### E) Operational guardrails
Ideas:
- Add alert-style metrics for: oldest queued age, stuck-running count, worker heartbeat staleness.
- Add a “repair queue” admin endpoint to re-publish or requeue tasks in known-safe cases.

Status:
- `skyforge_tasks_queued_oldest_age_seconds_total` (existing)
- `skyforge_tasks_running_oldest_age_seconds_total` (added)
- `skyforge_task_workers_heartbeat_age_seconds` (added)
- Admin repair endpoints exist:
  - `POST /api/admin/tasks/reconcile`
  - `POST /api/admin/tasks/reconcile-running`
