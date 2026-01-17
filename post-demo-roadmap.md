# Skyforge (TS Automation Platform) — Post-Demo Roadmap

This is a living list of follow-ups after the Encore-native + TanStack migration work and the LabPP/Netlab stabilization.

## Priority: Platform correctness

- **Self-hosted scheduling**
  - Done: worker emits heartbeats + runs reconciliation/maintenance loops without requiring Encore Cron.

- **Task artifacts from worker/taskengine**
  - Decide on one approach for persisting artifacts generated in `server/internal/taskengine` (LabPP CSV, Netlab tarballs, logs).
  - Implement a non-API storage client (or a dedicated worker-side API) instead of calling `storage.*` service APIs.
- **Cancellation hardening**
  - Current model: API marks task canceled + publishes cancel; worker performs runner cancellation.
  - Add idempotency + retries to cancellation (netlab cancel + k8s job delete) and record a task event when cancellation was applied.
- **Queue backpressure & observability**
  - Metrics: queued depth, queued→running latency, runtime duration (by task type), failure counts.
  - Add a simple “worker busy” signal in dashboard/status.

## Priority: UX polish (TanStack portal)

- **SSE everywhere it matters**
  - Runs/deployments update via SSE/Query invalidation (avoid “click to refresh” flows).
  - Tail logs in-place (client-side streaming; avoid re-opening dialogs).
- **Route parity cleanup**
  - Confirm all former Next.js pages/actions exist and remove dead links/redirects.
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
