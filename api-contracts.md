# Skyforge API contracts (stability guide)

This document captures the “don’t break lightly” contracts between:
- the Skyforge backend (Encore services),
- the browser UI (TanStack app served from `server/skyforge/frontend_dist`),
- and any external tooling that calls the API directly.

If you must break any of the below, bump `X-Skyforge-API-Version` and update the UI in the same change.

## Version headers

Skyforge returns the following headers on non-raw API responses:
- `X-Skyforge-API-Version`: a small integer string (currently `1`)
- `X-Skyforge-Build`: optional build identifier (git sha/tag)

Raw endpoints (SSE/WebSocket) set these headers when possible.

## Task/Run contract

Skyforge represents “runs” as tasks in Postgres.

Stable identifiers:
- `task_type` values are considered stable DB/API identifiers.
  - Examples: `netlab-c9s-run`, `containerlab-run`, `netlab-run`, `eve-ng-run`, `terraform-*`
- Do not rename task types without a DB migration / translation layer.

### Terraform runner binary resolution

- Terraform tasks resolve the executable in this order:
  1. `Terraform.BinaryPath` from typed Encore config.
  2. `terraform` found on `PATH` in the runtime container.
- Skyforge no longer downloads Terraform binaries at runtime.
- Operational requirement: worker/runtime images must include Terraform when
  Terraform tasks are enabled.

## SSE streaming contracts

### Run output

Endpoint:
- `GET /api/runs/:id/events` (raw SSE)

Events:
- `output`

Payload:
```json
{
  "cursor": 123,
  "entries": [
    { "createdAt": "RFC3339", "stream": "stdout|stderr", "output": "..." }
  ]
}
```

Notes:
- Clients may send `Last-Event-ID` to resume from a cursor.
- The server may send keep-alive comments (`: ping`).

### Dashboard snapshot

Endpoint:
- `GET /api/dashboard/events` (raw SSE)

Events:
- `snapshot`

Payload:
- a full dashboard snapshot object; fields may grow over time but should not be removed without a version bump.

## Auth contract

Skyforge exposes two browser login entry points, selected by runtime config:
- Local mode (`skyforge.auth.mode=local`): `POST /api/login` (via `/login/local` UI route)
- OIDC mode (`skyforge.auth.mode=oidc`): `GET /api/oidc/login?next=<path>`

Unauthenticated browser/tool redirects must use the same runtime-selected contract;
they must not hardcode OIDC-only behavior.

## URL prefix contract (UI + API)

Browser API base:
- `/api/*` (Gateway API route to Encore service)

Static assets:
- `/assets/skyforge/*`
