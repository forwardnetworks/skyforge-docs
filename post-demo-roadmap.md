# Skyforge (TS Automation Platform) — Post-Demo Roadmap

This is a living list of follow-ups after the Encore-native + TanStack migration work and the LabPP/Netlab stabilization.

## Priority: Platform correctness

- **Self-hosted scheduling**
  - Done: worker emits heartbeats + runs reconciliation/maintenance loops without requiring Encore Cron.

- **Task artifacts from worker/taskengine**
  - Done: taskengine persists artifacts directly to MinIO (`skyforge` bucket) without calling `storage.*` service APIs.
  - LabPP: stores `labpp/<deploymentID>/data_sources.csv` and sets `labppDataSourcesKey` on the task.
  - Netlab: stores `netlab/<deploymentID>/{netlab.snapshot.yml,clab.yml}` and sets `netlabSnapshotKey`/`netlabClabKey`.
  - Netlab C9s: stores `netlab-c9s/<deploymentID>/<tarball>` and sets `netlabC9sTarballKey`.
- **Cancellation hardening**
  - Done: cancellation is idempotent, retries runner cancellation, and records `cancel.requested`/`cancel.applied` task events.
- **Queue backpressure & observability**
  - Done: status summary includes a `task-queue` check with queued/running + oldest queued age.
  - Metrics already cover depth/latency/runtime by task type.

## Priority: UX polish (TanStack portal)

- **SSE everywhere it matters**
  - Runs/deployments update via SSE/Query invalidation (avoid “click to refresh” flows).
  - Tail logs in-place (client-side streaming; avoid re-opening dialogs).
- **Route parity cleanup**
  - Confirm all former portal pages/actions exist and remove dead links/redirects.
  - Normalize “Back/Done” behavior to return to the correct dashboard context.

## Priority: Netlab/Clabernetes roadmap

- **C9s day-0 workflow**
  - Validate container images availability (`ceos`, `vrnetlab/*`) and document the image import flow.
  - Document required host prerequisites (`/dev/kvm` etc.) for vrnetlab.
- **Netlab→C9s generation path**
  - Keep Netlab as a generator; clab tarball extraction to ConfigMaps must remain size-safe and deterministic.
  - Consider a future “clabverter” step if we need to normalize topologies before applying C9s.

## Optional refactors (later)

- **Remove unused legacy code paths**
  - Continue pruning leftover compatibility endpoints and configs that no longer have callers.
- **Security hardening**
  - Review RBAC/permissions for embedded tools (NetBox/Nautobot) and document the intended access model.
