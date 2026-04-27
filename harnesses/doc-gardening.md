# Doc Gardening Loop

Run this loop when docs feel stale, after major live incidents, or at least once
per release train.

## Inputs

- `git status --short`
- `find . -maxdepth 1 -iname '*handoff*.md' -o -iname '*resume*.md'`
- `rg -n 'k3d|local-only|skyforge-prod|old route|TODO|FIXME|handoff' components/docs AGENTS.md scripts`
- Recent completed execution-plan stubs under `exec-plans/completed/`
- Historical bodies under `archive/legacy/`

## Loop

1. Inventory stale or duplicated docs.
2. Compare claims against code, scripts, Helm values, and current environment docs.
3. Convert durable operational facts into Harness docs or active runbooks.
4. Move pure history to `archive/legacy/` and link it from `legacy-conversion-index.md`.
5. Update `quality-score.md` with grade, evidence, debt, and next target.
6. Run `make test-harness-docs` and the existing doc guards.
7. Keep the diff small; prefer several targeted cleanup PRs over one large rewrite.

## Promotion rule

If a doc rule prevents repeat incidents, encode it into a script or CI guard. If
it cannot be enforced mechanically, keep it short and link to the evidence that
justifies it.
