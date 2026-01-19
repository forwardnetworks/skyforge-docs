# Encore-native runs/workflows refactor plan

This document outlines a refactor path to make Skyforge “runs” and deployment workflows **event-driven** and “Encore-native”, while preserving backward compatibility during rollout.

Current state (as implemented):
- Runs are stored as tasks in Postgres (`sf_tasks`) with append-only output (`sf_task_logs`) and events (`sf_task_events`).
- Task execution is drained by the dedicated `worker` service (Pub/Sub subscriber + DB-backed state machine).
- The Skyforge API provides raw SSE endpoints for streaming without portal-side polling:
  - `GET /api/runs/:id/events` (task output)
  - `GET /api/dashboard/events` (dashboard snapshot stream)
  - Additional inbox streams (notifications/webhooks/syslog/snmp/workspaces) exist for the UI.
- Streaming uses Postgres `LISTEN/NOTIFY` as a lightweight wake-up signal and replays from DB by cursor.

Target state:
- Keep the current “task-as-run” model, but continue to refine:
  - workflow step boundaries (more granular step events)
  - explicit retries/reconciliation policies
  - richer event payloads for UI and auditability

## Goals

- Reduce “long handler does everything” failure modes.
- Make multi-step workflows resumable and idempotent.
- Stream status/output without client polling.
- Enable fan-out side effects (Forward upload, artifact indexing, notifications) without coupling.

## Non-goals (initially)

- Rewriting every existing runner implementation at once.
- Removing existing API endpoints; keep current UX stable.
- Perfect ordering across independent workspaces; correctness > ordering.

## Proposed primitives

### SQL tables (conceptual)

Keep existing run/task schema, but add (or emulate) these concepts:

- `runs` (one row per run)
  - `id`, `workspace_id`, `deployment_id`, `status`, `created_at`, `started_at`, `finished_at`, `error`
  - `active_step` (optional), `attempt` (optional)
  - `last_event_seq` (monotonic for replay)

- `run_events` (append-only event log; can be DB or S3-backed)
  - `run_id`, `seq` (per-run monotonic), `time`, `type`, `payload_json`
  - `output` field for `output_chunk` events (optional convenience)

You can keep today’s output store and “mirror” into it from events during Phase 1.

### Pub/Sub topics

Use a small number of topics with typed payloads:

- `RunRequestedTopic` (`at-least-once`, ordering by `run_id`)
  - “Start this run/workflow”

- `RunEventTopic` (`at-least-once`, ordering by `run_id`)
  - “This run produced a lifecycle/progress/output event”

Optional later:
- `RunReconcileTopic` (for delayed retries / step requeues)

### Event types

Keep a narrow, stable vocabulary:

- `run.queued`
- `run.started`
- `run.step.started`
- `run.step.succeeded`
- `run.step.failed`
- `run.output` (chunk)
- `run.warning`
- `run.artifact` (pointer to S3/object key)
- `run.succeeded`
- `run.failed`

For step events, include:
- `step_key` (e.g. `sync-template`, `netlab-create`, `clabernetes-apply`, `forward-upload`)
- `attempt`
- `duration_ms`
- `error` (when failed)

## Server layout (recommended)

Split responsibilities into small packages/services over time:

- `runs` service: create runs, persist state, publish/subscribe run events, expose streaming endpoints.
- `deployments` service: user-facing deployment APIs; translates actions into run requests.
- `runners/*`: provider-specific execution (netlab/labpp/containerlab/clabernetes).
- `forward` integration: Forward API calls and device upload formats.
- `blueprints` integration: template resolution/sync.

This can be a gradual refactor; start in-place if needed.

## Phased rollout plan

### Phase 0 — Define events (no behavior change)

1) Introduce a `RunEvent` type and `RunEventTopic`.
2) Add a helper `EmitRunEvent(ctx, runID, type, payload)` used by existing code paths.
3) Publish basic lifecycle events from existing run code:
   - queued, started, succeeded/failed, output chunks (if already chunked)

Outcome: you now have a consistent event stream without changing orchestration.

Status:
- Implemented using DB-backed task logs/events + SSE endpoints keyed by `task_id`.

### Phase 1 — Event mirror subscriber (keeps current DB/output)

Add a subscriber for `RunEventTopic` that:

- Appends events to `run_events` (with a per-run `seq`).
- Updates the `runs` row status/timestamps.
- Mirrors `run.output` into the existing output storage (so current `/runs/:id/output` continues to work).

Key implementation details:

- **Idempotency**: dedupe on `(run_id, publisher_event_id)` or `(run_id, seq)` assigned by the subscriber, not the publisher.
- **Ordering**: configure `OrderingAttribute` to `run_id` to avoid interleaving events per run.

Outcome: the authoritative state and output are driven by the subscriber, not whichever handler happens to run last.

### Phase 2 — Server-native SSE for UI (replace portal polling)

Add a Go **raw SSE endpoint** (Encore raw endpoint) on the server:

- `GET /api/skyforge/api/runs/:id/events` (SSE)
  - Uses `Last-Event-ID` to replay from `run_events.seq`
  - Streams new events as they are appended

Implementation approach:

- Replay: query `run_events` from `seq > last_event_id` (bounded page size).
- Tail: short sleep + query loop, or an in-memory fanout per run keyed by `run_id`.

Outcome: UI streams directly from the source-of-truth (server) and avoids duplicate compute in the portal.

Status:
- Implemented. The frontend consumes server-provided SSE endpoints and uses cursors (`Last-Event-ID`) for replay.

### Phase 3 — Orchestration becomes event-driven

Refactor “start deployment” to become “request a run”:

- API handler:
  - validates inputs
  - creates run row (status `queued`)
  - publishes `RunRequestedTopic` with `{run_id, workspace_id, deployment_id, action, config_hash}`
  - returns immediately

Subscriber for `RunRequestedTopic`:

- Executes workflow steps (synchronously within subscriber or by enqueuing step events).
- Publishes `RunEventTopic` at each boundary:
  - `run.started`
  - `run.step.started/succeeded/failed`
  - `run.output` chunks
  - final `run.succeeded` / `run.failed`

Outcome: long-running operations no longer block HTTP handlers; retries and resumption become tractable.

### Phase 4 — Retries + reconciliation

Add `encore.dev/cron` jobs for:

- Stuck run detection (no events for N minutes while status active).
- Runner reconciliation (e.g., check netlab/clabernetes state).
- Cleanup/expiry (old logs/artifacts).

Optional:

- Use a “delayed retry” queue/topic or re-publish `RunRequested` with incremented attempt.

### Phase 5 — Service boundaries and scale

As complexity grows:

- Split large services into smaller Encore services.
- Introduce per-provider worker concurrency limits.
- Add feature flags to gate experimental paths (e.g. clabernetes).

## Compatibility plan

Maintain existing endpoints during migration:

- `/api/skyforge/api/runs` continues to list runs (from `runs` table).
- `/api/skyforge/api/runs/:id/output` continues to work (from mirrored output store or synthesized from `run_events`).
- Existing run “ids” remain stable.

## Notes on “Encore-native” vs “browser-native”

Encore-native for internal workflow:
- Pub/Sub topics + subscribers (fan-out and orchestration)
- Cron for periodic reconciliation
- Tracing/logging/metrics across the flow

Browser push:
- Implement **raw endpoints** for SSE/WebSockets and stream from the authoritative event log.
  - Encore won’t “auto-stream” Pub/Sub to browsers; you bridge it via raw HTTP streaming.

## Suggested next increments (low-risk)

1) Start publishing `RunEventTopic` events from the existing run code paths.
2) Add the `run_events` append-only table and the mirror subscriber.
3) Add server SSE endpoint for run output and switch the portal to consume it.

These three steps get most of the benefits without a big-bang workflow rewrite.
