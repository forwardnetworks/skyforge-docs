# Encore-native refactor notes (Skyforge)

This document captures the remaining “Encore-native alignment” work that is **not** implemented yet,
and what it would take to do it cleanly without regressing the current working system.

Status: the system currently uses a dedicated worker **Deployment** plus a dedicated worker **image**
(`-tags=skyforge_worker`) to ensure only the worker registers the PubSub subscription.

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
- API image: `encore build docker ... --services=skyforge,storage`
- Worker image: `encore build docker ... --services=taskworker,storage`

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

### Helm changes required
- Render the `ENCORE_RUNTIME_CONFIG` secret from Helm values (or manage it out-of-band) so the
  cluster deployment does not depend on environment-variable parsing.

## 3) Logging

Status:
- Task queue publishing and task-runner “error prints” now use `encore.dev/rlog` for better
  correlation in Encore traces.
- Large parts of the codebase still use `log.Printf`; we can continue migrating opportunistically.

## 4) Cron

Status:
- Kubernetes CronJobs were removed from the Helm chart.
- The system relies on Encore cron jobs (`cron.NewJob`) for task reconciliation.

## 5) Task queue metrics

Status:
- The task runner already records queue latency and run duration metrics.
- A periodic cron job updates current-depth gauges:
  - `skyforge_tasks_queued_current_total`, `skyforge_tasks_running_current_total`
  - `skyforge_tasks_queued_oldest_age_seconds_total`
  - Per-task-type: `skyforge_tasks_queued_current`, `skyforge_tasks_running_current`, `skyforge_tasks_queued_oldest_age_seconds`
