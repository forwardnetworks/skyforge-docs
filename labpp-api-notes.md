# LabPP API Notes (Skyforge)

This repository includes a minimal, standalone LabPP API server so Skyforge can run LabPP jobs without pulling the full `fwd` monorepo. The intent is **not** to replace or fork LabPP ownership, but to provide a small, self-contained service that wraps the existing LabPP core logic with a stable API for Skyforge.

## What we pulled in
- `labpp-api/core`: copied from `fwd/test/labpp` and kept as-is (template parsing, EVE-NG executor, UNL generation, device templates).
- `labpp-api/server`: new Spring Boot service that exposes a minimal API and wires the core library.

## What changed (minimal surface area)
- **New Spring Boot server** (`labpp-api/server`) with `/jobs` endpoints:
  - `POST /jobs` → start a job
  - `GET /jobs/{id}` → job status
  - `GET /jobs/{id}/log` → job log
- **Logging**: per-job logs are written to `${LABPP_LOG_DIR}` using Logback MDC `labppJobId`.
- Skyforge stores the LabPP job ID in task metadata to support follow-up actions like Forward sync.
- **NetBox config**: NetBox is supported via env vars and passed into `LabConfig`.
- **AWS/S3 hooks**: S3 upload/download/remove are now **no-ops** in the minimal server (logged as skipped).
- **Client integration**: config-push via Forward client SDK was removed (logs indicate the push is skipped).

## Configuration (env vars)
- `LABPP_API_PORT` (default `8080`)
- `LABPP_WORK_DIR` (default `/var/lib/skyforge/labpp-workspaces`)
- `LABPP_LOG_DIR` (default `/var/lib/skyforge/labpp-api/logs`)
- `LABPP_MAX_THREADS` (default `8`)
- `LABPP_NETBOX_URL`
- `LABPP_NETBOX_USERNAME`
- `LABPP_NETBOX_PASSWORD`
- `LABPP_NETBOX_MGMT_SUBNET` (CIDR used for management IPs)

## Why this approach
- Keeps Skyforge changes isolated and avoids pulling the full `fwd` build graph.
- Allows us to align the runtime API contract with Skyforge (`/jobs` endpoints) while preserving existing LabPP behavior.
- Makes it easier to iterate on Skyforge-specific infra without changing upstream LabPP core logic.

If upstream LabPP evolves, we can refresh `labpp-api/core` from `fwd/test/labpp` and keep the server wrapper stable.
