# Deployment task queue

Skyforge stores all deployment operations as tasks in `sf_tasks`. Tasks are
queued per deployment and run FIFO (first in, first out).

Canonical deployment operation endpoint:

- `POST /api/users/:id/deployments/:deploymentID/action`
  - body: `{"action":"create|start|stop|destroy|export"}`
  - action parsing is strict and typed:
    - accepted: `create`, `start`, `stop`, `destroy`, `export`
    - empty action defaults to `start`
    - unknown values return `invalid_argument`
  - response may include idempotency metadata:
    - `idempotent`, `noOp`, `reason`, `state.desired`, `state.observed`
    - `reason`: `queued`, `already_present`, `already_absent`, `in_flight_duplicate`, `cooldown_suppressed`
    - `state.desired|observed`: `present`, `absent`, `unknown`

Deployment config decoding is strict per provider type; unknown fields in
`deployment.config` are rejected with `failed_precondition` instead of being
silently ignored.

## Why this exists

If a user clicks an action multiple times (or multiple users act on the same
deployment), Skyforge accepts the requests and queues them instead of returning
`failed_precondition` due to an existing active run.

## Portal UI

On the deployments list page, Skyforge surfaces a queue summary per deployment:

- `activeTaskStatus`: `queued` or `running` when a task is in progress
- `queueDepth`: number of queued tasks behind the active task
- `activeTaskId`: the active task id shown in the "Last task" column

These fields are best-effort metadata for UI display; the authoritative source
is `sf_tasks`.

## Streaming run output (SSE)

Skyforge streams task output via Server-Sent Events (SSE) directly from the backend:

- Run output tail: `GET /api/skyforge/api/runs/:id/events`
- Dashboard snapshot stream: `GET /api/skyforge/api/dashboard/events`

The portal consumes these endpoints to avoid polling.

Implementation note: SSE streams block until new task logs/events arrive. In Postgres-backed deployments, this uses `LISTEN/NOTIFY` to avoid Redis PubSub fanout.

## Duplicate clicks / idempotency

Some runs include a `metadata.dedupeKey` value. When present, Skyforge will
return the existing queued/running task for the same `dedupeKey` instead of
creating a duplicate task (useful for double-clicks and refreshes).

## Preflight checks

Some run endpoints validate basic filesystem prerequisites up front (for example,
that configured data/config directories are writable) to fail fast with clearer
errors before enqueuing long-running jobs.

## Reconciliation

Skyforge runs periodic reconciler cron jobs to keep tasks from getting stuck:

- Queued tasks are re-published periodically so they aren't stranded if a publish fails.
- Long-running tasks with no recent output can be marked failed to avoid indefinite `running` status after crashes.

These cron jobs are scheduled via Encore Cron and run in the Skyforge backend.

## Helm infra config

Encore PubSub requires the Helm-shipped `infra.config.json` to stay in sync with `server/infra.config.json` (for example, NSQ PubSub topics/subscriptions).

To check drift locally:

```bash
cd skyforge
./scripts/check-infra-config-sync.sh
```

Deployment action contract + matrix checks:

```bash
cd skyforge
./scripts/check-deployment-action-contract.sh
./scripts/check-deployment-action-matrix.sh
```
