---
harness_kind: completed-exec-plan
status: completed
legacy_source: codex-handoff.md
converted_at: 2026-04-27
archived_at: 2026-04-27
environment: mixed
title: Legacy account/scope removal resume packet
systems_touched: API, DB, UI, docs, scripts
verification: preserved in converted legacy body
current_truth: components/docs/user-scope-loop-runbook.md; components/docs/harnesses/archive/legacy/docs/user-only-hard-cutover-plan.md
superseded_assumptions: see the Harness conversion notes and body sections for stale local/k3d/prod context details
archive_note: historical evidence only; use current_truth for active guidance
---

# Legacy account/scope removal resume packet

> Archived evidence note: this body is retained for provenance only. Use the `current_truth` frontmatter and the completed-plan stub for active guidance.

# Skyforge Codex Resume Handoff (Updated 2026-02-17)

Use this file to resume the same workstream on a different machine.

## Current Priority

Complete the removal of legacy `account` / `scope` / `account` ownership concepts and standardize on **per-user ownership** across API, DB, UI, 
docs, scripts, and filenames.

## Repo Topology

Skyforge is a meta repo with component repos as submodules:

- `components/server` (Encore/Go backend)
- `components/portal` (TanStack/Vite UI)
- `components/charts` (Helm)
- `components/docs` (docs/runbooks)
- `components/blueprints` (default templates)
- `vendor/netlab`

## What To Pull On A New Machine

1. Clone `https://github.com/forwardnetworks/skyforge.git`
2. Run `git submodule update --init --recursive`
3. Read `components/docs/docs/development/git-checkout.md`

No file-copy workflow is required.

## Active Workstream Snapshot

- Ownership migration is in-flight in server + portal + docs.
- Forward on-prem proxy path should remain canonical under `/fwd`.
- User asked to remove naming references from APIs and filenames, not just alias old names.
- User requested deterministic cleanup and simple UX; avoid restoring legacy terminology.

## Resume Commands

From meta repo root:

```bash
git status
git submodule status --recursive
git submodule foreach 'echo "--- $name"; git status -sb || true'
```

From server repo (`components/server`) for ownership migration status:

```bash
./scripts/ownership-cleanup-status.sh
./scripts/ownership-cleanup-iteration.sh
```

## Validation Commands

```bash
cd components/server && ENCORE_DISABLE_UPDATE_CHECK=1 encore check ./...
cd ../portal && pnpm install && pnpm type-check
cd ../charts && helm lint skyforge
```

## Build / Push / Deploy

```bash
cd components/server
./scripts/build-push-skyforge-server.sh --tag <tag>

cd ../..
helm -n skyforge upgrade --install skyforge ./components/charts/skyforge \
  --reuse-values \
  --set images.skyforgeServer=ghcr.io/forwardnetworks/skyforge-server:<tag> \
  --set images.skyforgeServerWorker=ghcr.io/forwardnetworks/skyforge-server:<tag>-worker
```

## Forward Notes

- Canonical ingress path is `/fwd`.
- Do not require SSH tunnel for normal same-subnet access.
- If Forward login/proxy regresses, inspect path rewrites/cookies and verify routed paths under `/fwd`.

## Handoff Prompt

For a fresh Codex session, use:

`Read CODEX_HANDOFF_2026-02-10.md and continue removing account/scope/account ownership terminology with per-user ownership only.`
