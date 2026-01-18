# Portal migration: Next.js → TanStack Router

## Goal

Replace the legacy Next.js portal with a TanStack Router SPA (`portal-tanstack/`) while keeping the Encore/Go backend (`server/`) as the source of truth for all state.

This aligns the frontend with an API-first architecture (Encore endpoints + auth cookies), avoids Next-specific server/runtime behaviors, and makes it easier to adopt event streaming (SSE) and client-side caching via TanStack Query.

## Current state

- `portal-tanstack/`: production portal (TanStack Router + TanStack Query, built with Vite and embedded into the `skyforge-server` image).

The TanStack portal mirrors the existing Traefik routing surface so the Kubernetes ingress can route all UI paths to `skyforge-server`:

- `/` (landing)
- `/dashboard/*` (deployments, runs, logs, templates)
- `/admin/*` (admin-only)
- `/webhooks` (webhook inbox)
- `/docs/*` (static docs)

## Migration approach (incremental)

1. **Routing + layout parity**
   - Mirror route structure (`/status`, `/dashboard/deployments`, etc.).
   - Reuse styling (Tailwind) and gradually port shared UI components.

2. **API client consolidation**
   - Move API calls to a shared client layer (fetch wrappers + typed DTOs) that can be used by both portals during transition.
   - Convert data fetching to TanStack Query hooks.

3. **Auth flow**
   - Keep the existing cookie-based login flow (Dex/OIDC).
   - Ensure protected routes handle 401s by redirecting to `/api/oidc/login` (or the existing login entrypoint).

4. **Streaming updates**
   - Replace polling/auto-refresh with SSE endpoints and subscribe via TanStack Query `queryClient.invalidateQueries` on events.

5. **Deployment cutover**
   - Build `portal-tanstack/` with Vite (`pnpm build`) and embed it into the `skyforge-server` image.
   - Flip the Helm server image tag (QA first, then prod) and validate end-to-end.
   - Retire and remove the legacy portal from the repo once stable.

## Notes

- The SPA server must rewrite unknown routes to `index.html` to support deep links (handled by `server/skyforge/frontend_spa_raw.go`).
- Assets are served under `/assets/skyforge/*` to avoid collisions with Coder’s `/assets/*` paths.
