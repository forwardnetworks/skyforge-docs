---
harness_kind: completed-exec-plan
status: completed
legacy_source: RESUME_INSTRUCTIONS_019c6973.md
converted_at: 2026-04-27
archived_at: 2026-04-27
environment: prod
title: Forward RWX scratch enforcement resume packet
systems_touched: Forward storage, deploy hardening, recovery scripts
verification: preserved in converted legacy body
current_truth: components/docs/storage-longhorn.md; components/docs/prod-promotion-checklist.md; components/docs/harnesses/environment-contracts.md
superseded_assumptions: see the Harness conversion notes and body sections for stale local/k3d/prod context details
archive_note: historical evidence only; use current_truth for active guidance
---

# Forward RWX scratch enforcement resume packet

> Archived evidence note: this body is retained for provenance only. Use the `current_truth` frontmatter and the completed-plan stub for active guidance.

# Resume Instruction Set (Recovered from rollout 019c6973-a4a1-75a0-b696-2326cb54f8cc)

Use this as the **first prompt** in a fresh Codex session started in `~/src/skyforge`.

You are resuming an interrupted Skyforge task. Continue from the exact checkpoint below.

## Objective
Re-run and validate Forward RWX scratch enforcement end-to-end in the live environment, then leave a ready-to-deploy status and e2e smoke readiness.

## Completed Work (already done)
1. RWX scratch contract was implemented/tightened in all 3 scripts:
- `scripts/bootstrap-forward-local.sh`
- `scripts/deploy-skyforge-prod-safe.sh`
- `scripts/recover-prod-after-reboot.sh`

2. Behavior already added:
- Enforce `forward-scratch-rwx` with `ReadWriteMany` (hard fail if non-RWX).
- Rewrite `scratch` PVC references from `forward-scratch` to `forward-scratch-rwx`.
- Remove `subPath` / `subPathExpr` from scratch mounts.
- Fail hard if any scratch mounts still contain `subPath` or `subPathExpr`.

3. Prior validation claim in `forward` namespace (`skyforge-prod` context):
- `forward-scratch-rwx` was `Bound` + `ReadWriteMany`.
- No workloads remained on `forward-scratch`.
- No scratch mounts retained `subPath` / `subPathExpr`.

## Where It Stopped
After the above summary, user replied `ok`. Next action had started: re-validating on live `forward` namespace and preparing clean ready-to-deploy handoff.

## Resume Actions (do now)
1. Re-check git working tree for these files only:
- `scripts/bootstrap-forward-local.sh`
- `scripts/deploy-skyforge-prod-safe.sh`
- `scripts/recover-prod-after-reboot.sh`

2. Re-run deterministic live checks in namespace `forward`:
- Confirm PVC `forward-scratch-rwx` exists, `Bound`, and has `ReadWriteMany`.
- Confirm no deploy/statefulset scratch volume still points to `forward-scratch`.
- Confirm no scratch `volumeMount` has `subPath` or `subPathExpr`.

3. Run the preferred deploy/recovery automation path to re-apply end-to-end (without broad unrelated changes).

4. Re-run the same checks post-run and report before/after evidence.

5. If clean, produce a concise “ready-to-deploy + e2e smoke can start” handoff.

## Guardrails
- Do not broaden scope beyond RWX scratch enforcement and direct deployment/recovery validation.
- Preserve existing repo patterns; no new dependencies.
- If live cluster access fails, report exact failing command and stop with a minimal next action.

## Expected Final Output Shape
- What was executed.
- Evidence (PVC mode/binding, bad-claim count, bad-mount count, rollout status).
- Remaining risks (if any).
- Explicit go/no-go for e2e smoke.
