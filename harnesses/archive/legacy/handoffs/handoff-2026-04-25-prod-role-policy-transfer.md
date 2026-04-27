---
harness_kind: completed-exec-plan
status: completed
legacy_source: codex-handoff-2026-04-25-prod-role-policy-transfer.md
converted_at: 2026-04-27
archived_at: 2026-04-27
environment: prod
title: Prod role policy rollout
systems_touched: Role policy, prod deploy, rollback evidence
verification: preserved in converted legacy body
current_truth: components/docs/platform-role-policy.md; components/docs/harnesses/environment-contracts.md
superseded_assumptions: see the Harness conversion notes and body sections for stale local/k3d/prod context details
archive_note: historical evidence only; use current_truth for active guidance
---

# Prod role policy rollout

> Archived evidence note: this body is retained for provenance only. Use the `current_truth` frontmatter and the completed-plan stub for active guidance.
> Absorbed into active docs on 2026-04-27: role-policy behavior lives in `components/docs/platform-role-policy.md`; prod deployment/context guardrails live in `components/docs/harnesses/environment-contracts.md`.

# Skyforge Handoff - Prod Role Policy Rollout

Date: 2026-04-25

## Scope

- Source workspace: `/Users/captainpacket/src/skyforge`
- Transfer target: `captainpacket@192.168.1.167:/home/captainpacket/src/skyforge`
- Active environment for this rollout: `prod`
- Environment mapping:
  - `skyforge.dc` / `skyforge.dc.forwardnetworks.com` = prod
  - `skyforge.local` / `skyforge.local.forwardnetworks.com` = QA
- Prod deploy host used: `arch@labpp-sales-prod01.dc.forwardnetworks.com`
- Prod chart values used: `values-prod-labpp-sales-prod01.yaml`

## Rolled Out Image

- API image: `ghcr.io/forwardnetworks/skyforge-server:20260425-role-policy-r1`
- Worker image: `ghcr.io/forwardnetworks/skyforge-server:20260425-role-policy-r1-worker`
- Helm release after rollout: `skyforge/skyforge` revision `79`, status `deployed`
- Restore point before this rollout: Helm revision `77` with image tag `20260425-prod-public-security-r1`

## Implemented Changes

- Added `lab-user` as the default normal-user role profile.
- Kept `demo-user` as a constrained/read-only-style profile with zero concurrent labs.
- Added DB-backed role profile definitions so admins can tune role capabilities, quotas, operating modes, and role-level API permissions without a code change.
- Added admin APIs for role profile definitions and role-profile API permission rules.
- Updated effective API permission resolution to check user-specific rules first, then role-profile rules.
- Added Admin Settings UI for role profiles under the Users area.
- Updated quick deploy defaults so `lab-user` can launch curated templates.
- Added docs at `components/docs/platform-role-policy.md`.
- Added migration `20260425120000_role_profile_definitions.up.sql`.

## Verification

Local verification before rollout:

```bash
cd /Users/captainpacket/src/skyforge/components/server
ENCORE_DISABLE_UPDATE_CHECK=1 encore test ./platform ./internal/rbacstore ./authn ./skyforge
```

```bash
cd /Users/captainpacket/src/skyforge
pnpm --dir components/portal exec biome check \
  components/portal/src/components/admin-users-role-profiles-card.tsx \
  components/portal/src/components/settings-admin-sections.tsx \
  components/portal/src/components/admin-users-platform-policy-shared.tsx \
  components/portal/src/hooks/use-admin-settings-platform-policy-drafts.ts \
  components/portal/src/lib/api-client-admin-platform.ts \
  components/portal/src/lib/api-client-admin-rbac.ts \
  components/portal/src/lib/query-keys.ts \
  components/portal/src/components/admin-overview-quick-deploy-card.tsx
```

Prod rollout command:

```bash
REMOTE=arch@labpp-sales-prod01.dc.forwardnetworks.com \
VALUES_FILE=values-prod-labpp-sales-prod01.yaml \
SKYFORGE_PUBLIC_BASE_URL=https://skyforge.dc.forwardnetworks.com \
SKYFORGE_FORWARD_PUBLIC_BASE_URL=https://skyforge-fwd.dc.forwardnetworks.com \
SKYFORGE_ALLOW_PROD_DEPLOY=true \
SKYFORGE_FORWARD_MASTER_MIN_READY_NODES=1 \
SKYFORGE_SERVER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:20260425-role-policy-r1 \
SKYFORGE_SERVER_WORKER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:20260425-role-policy-r1-worker \
SKYFORGE_DEPLOY_PHASE=upgrade-only \
bash ./scripts/deploy-skyforge-prod-safe.sh
```

Post-rollout evidence:

```text
Helm revision: 79 deployed
skyforge-server image=ghcr.io/forwardnetworks/skyforge-server:20260425-role-policy-r1 ready=1/1
skyforge-server-worker image=ghcr.io/forwardnetworks/skyforge-server:20260425-role-policy-r1-worker ready=1/1
https://skyforge.dc.forwardnetworks.com/api/health -> {"status":"ok", ...}
```

Migration evidence from `skyforge_server` DB:

```text
viewer	true	false	0
demo-user	true	false	0
lab-user	true	true	2
sandbox-user	true	false	3
trainer	true	false	5
integration-user	true	false	4
admin	true	false	50
```

## Notes For Continuing On Blackforge

- The repo has substantial pre-existing dirty state across server, portal, charts, and generated assets. Do not assume every dirty file belongs to the role-policy work.
- `components/server/frontend/frontend_dist` was regenerated by the server build.
- The deploy helper defaults still point at older/local prod defaults unless explicit prod variables are supplied. For prod, keep using:
  - `REMOTE=arch@labpp-sales-prod01.dc.forwardnetworks.com`
  - `VALUES_FILE=values-prod-labpp-sales-prod01.yaml`
  - `SKYFORGE_PUBLIC_BASE_URL=https://skyforge.dc.forwardnetworks.com`
  - `SKYFORGE_FORWARD_PUBLIC_BASE_URL=https://skyforge-fwd.dc.forwardnetworks.com`
  - `SKYFORGE_FORWARD_MASTER_MIN_READY_NODES=1`
- Prod is currently single-node. Do not use QA hostnames or QA context for prod deploys.
- The deploy script may hit SSA ownership conflicts from runtime patches and retry with `--force-conflicts`; that happened on this rollout and completed successfully.
