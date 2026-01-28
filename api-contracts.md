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
  - Examples: `netlab-c9s-run`, `containerlab-run`, `clabernetes-run`, `terraform-*`
- Do not rename task types without a DB migration / translation layer.

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

OIDC login entry point:
- `GET /api/oidc/login?next=<path>`

## URL prefix contract (UI + API)

Browser API base:
- `/api/skyforge/api/*` (Traefik route to Encore service)

Static assets:
- `/assets/skyforge/*`
