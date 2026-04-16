# Quick Deploy Profiling

Use this workflow when quick deploy feels slow in two different ways:

- the initial click takes a long time before Skyforge creates the deployment
- the deployment exists, but the topology still takes minutes to become usable

Treat those as two separate problems. The first is synchronous API latency in
`POST /api/quick-deploy/deploy`. The second is asynchronous task execution
after the deployment record already exists.

## Request-path timing

Skyforge now emits structured phase logs from `RunQuickDeploy`. Inspect them
from the API deployment:

```bash
kubectl -n skyforge logs deploy/skyforge-server --since=15m | rg "quick deploy request"
```

The key phases are:

- `catalog_loaded`
- `user_scope_resolved`
- `collector_config_ready`
- `resource_estimate_cached`
- `resource_estimate_skipped`
- `deployment_created`
- `lease_updated`
- `action_enqueued`

Each line includes:

- `elapsed_ms`: total request time from the start of the API call
- `phase_ms`: time spent since the previous phase

## What to look for

### Slow `collector_config_ready`

This means the request path is spending time on managed Forward prerequisite
checks before the deployment is even created.

Quick-deploy now checks for an existing managed collector config before forcing
a Forward tenant credential ensure. That avoids an unnecessary support-auth
round-trip when the user already has a valid collector config.

### Slow `resource_estimate_cached` or repeated estimate misses

The deployment create path should not block on a fresh template estimate. Quick
deploy now uses the cache only and skips the estimate entirely on a cache miss,
because the estimate is advisory metadata rather than a hard prerequisite for
launch.

If you still care about showing the estimate early, warm it from the catalog or
template-inspection page before launch.

### Slow `action_enqueued`

This points at deployment-action locking or queue contention. The request path
waits for the deployment action to enqueue successfully, and a busy deployment
lock can delay that phase.

## Async run timing

Once the deployment exists, switch to the run itself. Use the task lifecycle and
output streams:

- `GET /api/runs/<taskID>/lifecycle`
- `GET /api/runs/<taskID>/events`

Important lifecycle/output signals:

- `task.queued`
- `task.started`
- `task.runtime.phase`
- `kne.deploy.phase`
- `forward.devices.upload.succeeded`
- `forward.collection.started`
- `forward.collection.completed`
- `task.finished`

These separate:

- queue wait
- KNE/netlab bring-up
- config/apply/runtime stages
- Forward upload and collection

## Recommended workflow

1. Capture the browser/network timing for `POST /api/quick-deploy/deploy`.
2. Pull the matching `quick deploy request` log lines from `skyforge-server`.
3. Open the resulting deployment/run and inspect `/api/runs/<taskID>/lifecycle`.
4. If the slow part is request-path latency, optimize the API prerequisites.
5. If the slow part is runtime, optimize the task stages and cluster/runtime settings instead.

## Current likely wins

The first material wins to check are:

- avoid unnecessary Forward tenant ensure work when a managed collector config already exists
- avoid blocking create on a cache miss for supplemental template estimates
- profile queue wait separately from KNE bring-up
- profile Forward sync separately from KNE bring-up

Do not treat the total “quick deploy took 5 minutes” number as one bottleneck.
It is usually several smaller waits stacked together.
