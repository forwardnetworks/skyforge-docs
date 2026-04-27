# Legacy Conversion Index

This index routes old handoff and plan names to the current Harness location.
Do not link new docs to old root paths or the removed `components/docs/plans/`
directory.

## Converted root artifacts

| Legacy source | Completed stub | Archived evidence | Environment | Current truth |
| --- | --- | --- | --- | --- |
| `HANDOFF-2026-04-11-designer-forward.md` | [exec-plans/completed/HANDOFF-2026-04-11-designer-forward.md](exec-plans/completed/HANDOFF-2026-04-11-designer-forward.md) | [archive/legacy/handoffs/HANDOFF-2026-04-11-designer-forward.md](archive/legacy/handoffs/HANDOFF-2026-04-11-designer-forward.md) | mixed | [../kne-workflow.md](../kne-workflow.md), [../netlab-kne.md](../netlab-kne.md), [../storage-longhorn.md](../storage-longhorn.md) |
| `RESUME_INSTRUCTIONS_019c6973.md` | [exec-plans/completed/RESUME_INSTRUCTIONS_019c6973.md](exec-plans/completed/RESUME_INSTRUCTIONS_019c6973.md) | [archive/legacy/handoffs/RESUME_INSTRUCTIONS_019c6973.md](archive/legacy/handoffs/RESUME_INSTRUCTIONS_019c6973.md) | prod | [../storage-longhorn.md](../storage-longhorn.md), [../prod-promotion-checklist.md](../prod-promotion-checklist.md), [environment-contracts.md](environment-contracts.md) |
| `codex-handoff.md` | [exec-plans/completed/handoff.md](exec-plans/completed/handoff.md) | [archive/legacy/handoffs/handoff.md](archive/legacy/handoffs/handoff.md) | mixed | [../user-scope-loop-runbook.md](../user-scope-loop-runbook.md), [archive/legacy/docs/user-only-hard-cutover-plan.md](archive/legacy/docs/user-only-hard-cutover-plan.md) |
| `codex-handoff-2026-04-25-connectivity-and-ai-routing-validation.md` | [exec-plans/completed/handoff-2026-04-25-connectivity-and-ai-routing-validation.md](exec-plans/completed/handoff-2026-04-25-connectivity-and-ai-routing-validation.md) | [archive/legacy/handoffs/handoff-2026-04-25-connectivity-and-ai-routing-validation.md](archive/legacy/handoffs/handoff-2026-04-25-connectivity-and-ai-routing-validation.md) | prod+qa | [environment-contracts.md](environment-contracts.md) |
| `codex-handoff-2026-04-25-prod-nightly-demo-reset-check.md` | [exec-plans/completed/handoff-2026-04-25-prod-nightly-demo-reset-check.md](exec-plans/completed/handoff-2026-04-25-prod-nightly-demo-reset-check.md) | [archive/legacy/handoffs/handoff-2026-04-25-prod-nightly-demo-reset-check.md](archive/legacy/handoffs/handoff-2026-04-25-prod-nightly-demo-reset-check.md) | prod | [../forward-demo-reset-rollout-checklist.md](../forward-demo-reset-rollout-checklist.md) |
| `codex-handoff-2026-04-25-prod-role-policy-transfer.md` | [exec-plans/completed/handoff-2026-04-25-prod-role-policy-transfer.md](exec-plans/completed/handoff-2026-04-25-prod-role-policy-transfer.md) | [archive/legacy/handoffs/handoff-2026-04-25-prod-role-policy-transfer.md](archive/legacy/handoffs/handoff-2026-04-25-prod-role-policy-transfer.md) | prod | [../platform-role-policy.md](../platform-role-policy.md), [environment-contracts.md](environment-contracts.md) |
| `codex-handoff-2026-04-27-iol-startup-priv-escalation-and-encore-cfg-encoding.md` | [exec-plans/completed/handoff-2026-04-27-iol-startup-priv-escalation-and-encore-cfg-encoding.md](exec-plans/completed/handoff-2026-04-27-iol-startup-priv-escalation-and-encore-cfg-encoding.md) | [archive/legacy/handoffs/handoff-2026-04-27-iol-startup-priv-escalation-and-encore-cfg-encoding.md](archive/legacy/handoffs/handoff-2026-04-27-iol-startup-priv-escalation-and-encore-cfg-encoding.md) | prod | [../netlab-kne.md](../netlab-kne.md), [environment-contracts.md](environment-contracts.md) |
| `codex-handoff-2026-04-27-prod-demo-cron-quickdeploy-iol.md` | [exec-plans/completed/handoff-2026-04-27-prod-demo-cron-quickdeploy-iol.md](exec-plans/completed/handoff-2026-04-27-prod-demo-cron-quickdeploy-iol.md) | [archive/legacy/handoffs/handoff-2026-04-27-prod-demo-cron-quickdeploy-iol.md](archive/legacy/handoffs/handoff-2026-04-27-prod-demo-cron-quickdeploy-iol.md) | prod | [../forward-demo-reset-rollout-checklist.md](../forward-demo-reset-rollout-checklist.md), [../quick-deploy.md](../quick-deploy.md), [../netlab-kne.md](../netlab-kne.md) |

Completed stubs are routing artifacts. Their full historical bodies live under
`archive/legacy/handoffs/` and are evidence only.

## Converted legacy plan directory

The old `components/docs/plans/` directory has been folded into Harness active
execution plans. Each active plan keeps `legacy_source` metadata for provenance;
that metadata is not a surviving path to open.

- [exec-plans/active/change-control-migration.md](exec-plans/active/change-control-migration.md)
- [exec-plans/active/change-plan-workflow.md](exec-plans/active/change-plan-workflow.md)
- [exec-plans/active/designer-eve-gns3-parity-migration.md](exec-plans/active/designer-eve-gns3-parity-migration.md)
- [exec-plans/active/long-term-architecture-skyforge-netlab-kne.md](exec-plans/active/long-term-architecture-skyforge-netlab-kne.md)
- [exec-plans/active/marketing-snapshot-config-changes.md](exec-plans/active/marketing-snapshot-config-changes.md)
- [exec-plans/active/netlab-k8s-plugin-migration.md](exec-plans/active/netlab-k8s-plugin-migration.md)
- [exec-plans/active/netlab-sot-hardcut.md](exec-plans/active/netlab-sot-hardcut.md)
- [exec-plans/active/server-portal-hard-cut-migration-checklist.md](exec-plans/active/server-portal-hard-cut-migration-checklist.md)
- [exec-plans/active/skyforge-capacity-policy-platform-plan.md](exec-plans/active/skyforge-capacity-policy-platform-plan.md)
- [exec-plans/active/teams-forward-integration.md](exec-plans/active/teams-forward-integration.md)

These are active/reusable until they are completed with evidence or archived as
obsolete.

## Historical docs archived into Harness

Former `components/docs/archive/legacy/` material now lives under
`archive/legacy/docs/`:

- [archive/legacy/docs/compatibility-hard-cut.md](archive/legacy/docs/compatibility-hard-cut.md)
- [archive/legacy/docs/encore-native-refactor.md](archive/legacy/docs/encore-native-refactor.md)
- [archive/legacy/docs/encore-native-runs-plan.md](archive/legacy/docs/encore-native-runs-plan.md)
- [archive/legacy/docs/user-only-hard-cutover-plan.md](archive/legacy/docs/user-only-hard-cutover-plan.md)

## Conversion policy

- Active truth belongs in `components/docs/` runbooks or `harnesses/*.md`, not
  in archived handoff bodies.
- `legacy_source` records provenance only. Do not treat it as a path to open.
- If a converted file contains a command that still matters, move that command
  into the active runbook and leave only an archive pointer here.
- Pure history belongs under `components/docs/harnesses/archive/legacy/`.
