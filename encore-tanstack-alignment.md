# Encore + TanStack Alignment Checklist (Skyforge)

This is the “do first” architecture checklist for the TanStack portal migration so we don’t have to redo work later.

## Goals
- **Single source of truth:** server state lives in Skyforge; UI is a cache/view.
- **Live UX:** use SSE for status/logs instead of manual refresh/polling where possible.
- **Consistent auth:** one redirect contract for login/logout across all pages.
- **Typed boundary:** typed, centralized API client (no inline `fetch` in components).
- **Stable platform contracts:** no URL/path collisions with other tools (Coder, Git, etc).

## Contracts to lock down (don’t break)
- **Portal assets:** served under `/assets/skyforge/*` (avoid Traefik `/assets/*` → Coder).
- **Encore API base (browser):** `/api/skyforge/api/*` (Traefik rewrites to the Encore service).
- **Platform status:** `/status/summary` (plus SSE at `/status/summary/events`).
- (Legacy) **Platform health JSON:** `/data/platform-health.json` (served from live checks; no filesystem dependency).
- **OIDC login entry:** `GET /api/skyforge/api/oidc/login?next=<path>`.

## Client architecture (TanStack)
### Query model
- Use **TanStack Query** as the single cache/store for server state.
- Prefer **query keys** defined in one place (a `queryKeys` module).
- Do not manage “duplicated state machines” in components.

### SSE model
- SSE handlers should only:
  - `queryClient.setQueryData(...)` or
  - `queryClient.invalidateQueries(...)`
- Components should only read from queries.
- Prefer a small number of “streams”:
  - `dashboard snapshot` stream: `/api/skyforge/api/dashboard/events`
  - `run output` stream: `/api/skyforge/api/runs/:id/events`

### Auth model
- Use one `useSession()` query that calls `GET /api/skyforge/api/session`.
- On `401/403` from authenticated endpoints:
  - redirect to `.../oidc/login?next=<current location>`
- Only guard **protected routes** (e.g. `/dashboard/*`, `/admin/*`).

### Error model
- Centralize API errors into a single `ApiError` with:
  - `status`, `message`, and optional `details`/response text.
- Render a consistent “error state” component for:
  - network errors, unauthorized, forbidden, server errors.

## Backend architecture (Encore)
### Task execution
- Request endpoints enqueue tasks and return quickly.
- Workers execute tasks and append logs.
- SSE endpoints stream logs/state (`dashboard/events`, `runs/:id/events`).
- Avoid shared-disk side effects in tasks where possible (prefer DB/object storage + per-task temp dirs).

### Bootstrap behavior
- `user-bootstrap` tasks should not clone repos or write to shared user home directories; they only provision downstream integrations (e.g. Gitea user + catalog repos).

### Observability
- Metrics to add/keep:
  - queue depth
  - task latency (queued → started → finished)
  - worker concurrency

## Migration approach (avoid redo)
1) Lock in the above contracts + shared client libs.
2) Port the shell (layout/nav/theme) once.
3) Port screens page-by-page, using the shared API/query/SSE layers.
4) Only then start deeper UX polish.

## Regenerating generated files
- `./scripts/regen-generated.sh`

Generated files are marked in `.gitattributes` to reduce review noise.
