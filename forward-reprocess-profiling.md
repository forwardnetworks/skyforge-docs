# Forward Reprocess Profiling

Use this workflow when a Forward snapshot reprocess looks stuck, the ETA swings
wildly, or you need to decide whether cluster-wide tuning can help without
changing Forward code.

The profiler is intentionally attach-first. Start it before or immediately
after you trigger a reprocess so the first sample lands before the heavy phase.

## Quick start

Attach to an already-running reprocess:

```bash
python3 scripts/profile-forward-reprocess.py \
  --sample-interval-seconds 30
```

Stop it with `Ctrl-C` after the reprocess completes or after you have enough
samples for the slow phase.

Run it as a controlled experiment with a repeatable trigger command:

```bash
python3 scripts/profile-forward-reprocess.py \
  --sample-interval-seconds 30 \
  --start-command '<your curl or helper command here>'
```

Notes:

- `--max-samples` counts the initial baseline sample too.
- `--pressure-sample auto` is the default. The profiler captures one node
  pressure snapshot from the hottest compute node once a compute worker crosses
  roughly `4` vCPU.
- The tool does not know how to start a generic Forward reprocess on its own.
  Use the UI, your own `curl` wrapper, or a local helper command.

## Artifacts

Each run writes a timestamped directory under `artifacts/` with:

- `reprocess-samples.csv`: pod and node CPU/memory samples
- `reprocess-db-counters.csv`: app/FDB wait summaries plus FDB WAL and tuple counters
- `reprocess-events.log`: filtered `fwd-backend-master`/`fwd-appserver` log lines and node events
- `reprocess-summary.md`: classification and headline findings
- `node-pressure-<node>.txt`: optional one-shot pressure sample from the hottest node
- `start-command.log`: optional stdout/stderr from `--start-command`

## What the profiler captures

Every sample interval it records:

- `kubectl -n forward top pods` for `fwd-compute-worker`, `fwd-search-worker`,
  `fwd-backend-master`, `fwd-appserver`, and `fwd-collector`
- `kubectl top nodes`
- pod placement and readiness from `kubectl -n forward get pods -o json`
- `pg_stat_activity` wait summaries from the app primary and both FDB primaries
- FDB progress counters using `pg_wal_lsn_diff(...)`, `xact_commit`, and tuple counters
- filtered `SEVERE`/`ERROR`/`WARN`/`timeout`/`snapshot` log lines from the appserver and backend master
- node events for the nodes currently running Forward pods

## Reading the result

The summary classifies the run using the sampled evidence instead of the Forward
ETA. Use the classification as the first filter:

- `compute-dominant and only partially parallelized`:
  - compute workers are hot
  - search workers are mostly idle
  - FDB WAL keeps advancing
  - DB wait pressure is absent
  - cluster-wide CPU and memory are not saturated
- `database wait pressure`:
  - sampled waits show `Lock`, `LWLock`, `BufferPin`, or `IPC`
  - app/FDB contention is more likely than raw worker shortage
- `storage or memory pressure on the hottest worker node`:
  - node PSI shows meaningful I/O or memory pressure during the hot phase
- `node stability risk`:
  - the sampled window includes `NodeNotReady` events
  - fix node health before tuning replicas or JVM flags
- `FDB WAL counters did not advance`:
  - the run may actually be stalled, or the wrong snapshot/run window was observed

## Recommended experiment order

### 1. Prove the run is progressing

Do not trust the UI ETA by itself. If `wal_bytes` and `xact_commit` keep moving
while hot compute workers stay busy, the job is progressing even if the ETA
looks frozen.

### 2. Keep worker runtime explicit

For upstream-owned workers, the current runtime source of truth is:

```yaml
skyforge:
  forwardCluster:
    upstreamWorkerRuntime:
      compute:
        memoryProfile: ISOLATED_WORKER
        memoryLimitMB: 16384
        podMemoryRequest: 8Gi
        podMemoryLimit: 24Gi
      search:
        memoryProfile: ISOLATED_WORKER
        memoryLimitMB: 8192
        podMemoryRequest: 4Gi
        podMemoryLimit: 12Gi
```

The repair scripts re-apply these values after upstream Forward reconciliation
so worker heap settings do not drift.

### 3. Try the vector-module experiment

Forward logs warn that optimal vector performance needs the incubator module.
The repo now exposes an IaC-safe knob for that experiment.

For upstream-owned workers:

```yaml
skyforge:
  forwardCluster:
    upstreamWorkerRuntime:
      compute:
        javaToolOptions: "--add-modules jdk.incubator.vector"
      search:
        javaToolOptions: "--add-modules jdk.incubator.vector"
```

If Skyforge owns the worker manifests, use the parallel knob instead:

```yaml
skyforge:
  forwardCluster:
    workers:
      compute:
        javaToolOptions: "--add-modules jdk.incubator.vector"
      search:
        javaToolOptions: "--add-modules jdk.incubator.vector"
```

Run one fresh reprocess before and after the change. Keep it only if elapsed
time or the slowest phase improves materially and no new runtime errors appear.

### 4. Decide whether more nodes can help

Use the profiler output, not intuition:

- if the median active compute-worker count is already high and FDB WAL
  advances proportionally, more worker-capable nodes may help
- if only `2-3` compute workers stay hot while the rest remain cool, more nodes
  are unlikely to matter
- larger nodes are usually the wrong first move unless individual workers are
  CPU throttled or memory-constrained

## Cluster-wide guidance

What tends to help:

- every intended worker-capable node actually labeled and `Ready`
- explicit upstream worker heap/runtime settings
- stable node health with no `NodeNotReady` flaps during reprocess
- one controlled JVM flag experiment at a time

What usually does not help:

- adding CPU or RAM to already-underutilized nodes
- chasing the UI ETA without sampling actual worker, DB, and node progress
- changing multiple tuning levers at once

## Example workflow

1. Start the profiler.
2. Trigger the reprocess.
3. Wait until the slow phase has at least a few samples.
4. Stop the profiler.
5. Read `reprocess-summary.md`.
6. If the run is compute-dominant, test the vector-module flag next.
7. If the run shows DB waits, storage pressure, or node flaps, fix that first.
