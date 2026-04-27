# Agent Operating Model

## Default loop

1. Read `AGENTS.md` for routing.
2. Open the Harness index and the domain runbook for the task.
3. Inspect code/config/live state before changing anything.
4. Make the smallest reversible change that satisfies the task.
5. Run the narrowest meaningful validation first, then broader gates when needed.
6. Convert durable findings into docs, checks, or completed execution plans.

## Execution plans

Use `exec-plans/active/` for work that may span sessions or operators. Use
`exec-plans/completed/` for rollout evidence, incident handoffs, and migration
history that future agents should be able to mine without searching chat logs.

Completed execution plans must include frontmatter with:

- `harness_kind: completed-exec-plan`
- `status: completed`
- `source_path`
- `converted_at`
- `environment`
- `systems_touched`
- `verification`
- `current_truth`
- `superseded_assumptions`

## Reviews

For code and live operations, prefer independent agent review for security,
correctness, and verification evidence. Treat reviewer output as advisory until
verified against repo files, tests, or live state.

## Handoffs

Do not create new root-level handoff files. Put new handoffs in
`exec-plans/active/` while active, then move them to `exec-plans/completed/`
with evidence and current-truth notes when done.
