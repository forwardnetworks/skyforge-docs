# Portal migration: Next.js → TanStack Router

## Goal

Replace the current Next.js portal (`portal/`) with a TanStack Router SPA (`portal-tanstack/`) while keeping the Encore/Go backend (`server/`) as the source of truth for all state.

This aligns the frontend with an API-first architecture (Encore endpoints + auth cookies), avoids Next-specific server/runtime behaviors, and makes it easier to adopt event streaming (SSE) and client-side caching via TanStack Query.

## Current state

- `portal-tanstack/`: production portal (TanStack Router + TanStack Query, served by Nginx on port `3000`).
- `portal/`: legacy Next.js portal kept for a rollback window.

The TanStack portal mirrors the existing Traefik routing surface so the Kubernetes ingress can continue routing all paths to `skyforge-portal`:

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
   - Build/push `skyforge-portal` from `portal-tanstack/`.
   - Flip the Helm image tag (QA first, then prod) and validate end-to-end.
   - Keep `portal/` for a rollback window, then delete once stable.

## Notes

- The SPA server must rewrite unknown routes to `index.html` to support deep links (handled by `portal-tanstack/nginx.conf`).
- The Kubernetes ingress can keep routing all paths to `skyforge-portal`; the SPA will handle client-side routing.
