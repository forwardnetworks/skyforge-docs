# User-Context Cutover Final Plan

## Goal
Enforce a user-only ownership model in Skyforge runtime behavior and remove the legacy shared-container model.

## Success Criteria
- No shared-container CRUD, selector, or settings flows remain in active UX.
- Active backend runtime paths are user-scoped only.
- Generated API artifacts are refreshed to match user-context endpoints.
- A CI/ops gate exists to prevent legacy terminology from re-entering active source paths.

## Scope
- `components/server`
- `components/portal`
- `components/charts`
- `components/docs`
- `scripts/ops` in the meta repo

## Out of Scope
- Rewriting historical migration history.
- Re-introducing sharing/teams in this pass.
- Removing historical handoff records.

## Implementation Plan
1. Backend API and task semantics
2. Frontend route/state cleanup
3. Generated artifact refresh (OpenAPI and TS client)
4. Chart/config terminology cleanup
5. Documentation rewrite/archive
6. Regression gate and acceptance checks

### 1) Backend API and Task Semantics
- Keep ownership keyed to user context (`user_id`/owner context).
- Remove remaining legacy endpoint naming from active handlers and user-facing messages.
- Ensure lock/dedupe/task semantics are user-scoped.

### 2) Frontend Route/State Cleanup
- Remove shared-container selector dependencies from active dashboard/deploy flows.
- Keep all user-facing flows driven by current user context.
- Normalize Forward UI path usage to `/fwd`.

### 3) Generated Artifact Refresh
- Regenerate `components/server/skyforge/openapi.json`.
- Sync generated server OpenAPI into chart copy.
- Regenerate `components/portal/src/lib/openapi.gen.ts`.

### 4) Chart and Config Cleanup
- Remove legacy wording from active chart templates and values comments.
- Keep only compatibility keys required by runtime config schema.

### 5) Documentation Cleanup
- Update active docs to user-context language.
- Keep historical docs in archive locations when needed.

### 6) Regression Gate
- Add an ops script that fails on legacy ownership terminology in active source paths.
- Allowlist only generated, historical, or legacy artifact paths.

## Validation
- Server compile/check:
  - `cd components/server && ENCORE_DISABLE_UPDATE_CHECK=1 go test ./...` (noting Encore runtime package caveats)
- Portal checks:
  - `cd components/portal && pnpm lint && pnpm type-check`
- Terminology gate:
  - `scripts/ops/terminology-gate.sh`

## Acceptance
- Active source paths pass terminology gate.
- OpenAPI + portal generated client are refreshed.
- User deployment flows no longer require shared-container constructs.
