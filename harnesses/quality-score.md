# Quality Score

This table gives agents a compact quality map. Update it when a domain changes,
when doc gardening finds drift, or when a completed execution plan supersedes an
old assumption.

| Domain | Grade | Last checked | Evidence | Known debt | Next cleanup target |
| --- | --- | --- | --- | --- | --- |
| Harness structure | B+ | 2026-04-27 | `scripts/check-harness-docs.sh` | New; completed stubs and archive guards need repeated use | Run one doc-gardening pass after first implementation PR |
| Environment contracts | A- | 2026-04-27 | `environment-contracts.md`, `../environment-profiles.md` | Some legacy local/k3d references still exist in old docs | Move stale local-only guidance to archive or mark QA-only |
| Prod deploy safety | A- | 2026-04-27 | `environment-contracts.md`, `../prod-promotion-checklist.md`, deploy scripts | Runtime patch conflict handling still depends on final rollout verification | Keep rollback/image examples in environment docs current |
| Netlab + KNE | B+ | 2026-04-27 | `architecture-boundaries.md`, `../netlab-kne.md` | Historical incident docs still overlap, but active startup-mode contract is consolidated | Deduplicate older KNE narrative sections after one more prod/QA validation |
| Forward demo orgs | B+ | 2026-04-27 | `../forward-demo-reset-rollout-checklist.md` | Runbook has durable contract; older March 31 baseline remains for incident comparison | Archive stale baseline once the next nightly run is captured cleanly |
| Quick Deploy | B+ | 2026-04-27 | `../quick-deploy.md`, `legacy-conversion-index.md` | Catalog contract is active, but source-discovery edge cases still need periodic runtime checks | Add a small catalog-source decision table if new source classes appear |
| Legacy docs | B+ | 2026-04-27 | `legacy-conversion-index.md`, `archive/legacy/README.md` | Legacy bodies are archived; some active docs still carry historical comparison sections | Archive stale baseline sections after current runtime evidence replaces them |
