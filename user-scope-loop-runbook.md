# User-Scope Cleanup Loop Runbook

This runbook defines the repeatable loop to remove remaining legacy ownership semantics (`userScope/project/account`) from active Skyforge runtime code.

## Loop command

From repo root:

```bash
bash scripts/run-user-scope-loop.sh quick
```

For a full gate (includes portal build + server tests):

```bash
bash scripts/run-user-scope-loop.sh full
```


## Iterative loop wrapper

To run repeated cleanup passes automatically with stall detection:

```bash
bash scripts/run-user-scope-loop-iterate.sh quick 20 2
```

Arguments:

- `quick|full`: loop mode
- `max_iters`: max passes before stop
- `stall_limit`: stop after N non-improving passes

Logs are written under `.codex-loop/user-scope-<timestamp>/`.

## What each loop validates

1. `scripts/check-user-scope-hard-cut.sh`
2. `scripts/check-stale-routes.sh`
3. `scripts/check-portal-terminology.sh`
4. Residual symbol counts in active server/portal source
5. (`full` mode) portal build + server test

## Active-source scope

The loop excludes:

- migrations/history
- generated dist assets
- generated OpenAPI artifacts
- archived docs

It targets active code paths only.

## Schema baseline status

- Migration history has been hard-cut to a single baseline migration:
  - `components/server/internal/skyforgedb/migrations/20260222170000_user_scope_baseline.up.sql`
- This is destructive by design for legacy upgrade paths. New and reset environments must migrate from this baseline.

## Iteration workflow

1. Run `quick`.
2. Fix one concentrated cluster (for example, deployments API + portal deployments routes).
3. Re-run `quick`.
4. When quick is clean for that cluster, run `full`.
5. Repeat until residual counts and targeted `rg` scans are at the accepted baseline.

## Completion criteria

Use this loop until:

1. Guard scripts pass.
2. `full` gate passes.
3. Residual counts stop decreasing only because remaining terms are provider-native or explicitly allowlisted.
4. Deploy checkpoint is executed after a full-gate pass.
