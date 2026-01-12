# Deployment task queue

Skyforge stores all deployment operations as tasks in `sf_tasks`. Tasks are
queued per deployment and run FIFO (first in, first out).

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

## Duplicate clicks / idempotency

Some runs include a `metadata.dedupeKey` value. When present, Skyforge will
return the existing queued/running task for the same `dedupeKey` instead of
creating a duplicate task (useful for double-clicks and refreshes).

## Preflight checks

Some run endpoints validate basic filesystem prerequisites up front (for example,
that configured data/config directories are writable) to fail fast with clearer
errors before enqueuing long-running jobs.
