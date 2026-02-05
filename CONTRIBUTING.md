# Contributing to Skyforge

Thanks for taking the time to contribute. This repo targets a production-style k3s deployment and a clean OSS experience.

## Code of Conduct
By participating, you agree to the Code of Conduct in `CODE_OF_CONDUCT.md`.

## Quick start
- Read `docs/quickstart.md` for the single-node k3s flow.
- Read `docs/configuration.md` for environment and branding settings.
- Read `docs/smoke-tests.md` for health checks.

## Repo layout
- `server/` — Encore service code (API, integrations, orchestration).
- `portal-tanstack/` — TanStack Router + Vite UI.
- `k8s/` — Kubernetes manifests and overlays (k3s-first).
- `docs/` — deployment + maintenance docs.

## Development workflow
1) Create a feature branch from `main`.
2) Make focused changes with clear commit messages.
3) Keep secrets out of the repo (`./secrets` is gitignored).
4) Update or add docs when behavior changes.

## Commit hygiene
- Prefer small, scoped commits.
- Include the area and intent in the message (e.g., `portal: refine deployments layout`).

## Testing
- Use the smoke checks in `docs/smoke-tests.md` for validation.
- If you touch API contracts, re-generate the OpenAPI spec and TypeScript client:
  - `./scripts/gen-openapi.sh`
  - `cd portal-tanstack && pnpm gen:openapi`

## Issues & PRs
- File bugs or feature requests via GitHub issues.
- Keep PRs small and link to an issue when possible.

Thanks again for improving Skyforge.
