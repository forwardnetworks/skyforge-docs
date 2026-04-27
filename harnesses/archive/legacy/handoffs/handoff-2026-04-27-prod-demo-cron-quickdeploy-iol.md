---
harness_kind: completed-exec-plan
status: completed
legacy_source: codex-handoff-2026-04-27-prod-demo-cron-quickdeploy-iol.md
converted_at: 2026-04-27
archived_at: 2026-04-27
environment: prod
title: Demo cron durability, quick deploy, and IOL startup mode
systems_touched: Demo org cron, quick deploy catalog, Netlab/IOL
verification: preserved in converted legacy body
current_truth: components/docs/forward-demo-reset-rollout-checklist.md; components/docs/quick-deploy.md; components/docs/netlab-kne.md
superseded_assumptions: see the Harness conversion notes and body sections for stale local/k3d/prod context details
archive_note: historical evidence only; use current_truth for active guidance
---

# Demo cron durability, quick deploy, and IOL startup mode

> Archived evidence note: this body is retained for provenance only. Use the `current_truth` frontmatter and the completed-plan stub for active guidance.
> Absorbed into active docs on 2026-04-27: demo reset durability lives in `components/docs/forward-demo-reset-rollout-checklist.md`, quick deploy catalog rules live in `components/docs/quick-deploy.md`, and IOL startup-mode validation lives in `components/docs/netlab-kne.md`.

# Skyforge prod handoff: demo cron durability, quick deploy catalog, IOL startup mode

Date: 2026-04-27
Environment: prod (`arch@labpp-sales-prod01.dc.forwardnetworks.com`)
Kubeconfig used locally: `/tmp/kubeconfig-prod-labpp`
Active context guard: `~/.skyforge-active-context` must contain `prod`

## Scope

This handoff covers three linked prod fixes:

1. Demo-org nightly reset must repair all shareable users durably.
2. Quick Deploy must be tag-driven and include eligible public Gitea labs, including `craigjohnson/skyforge-training/labs`.
3. IOL/IOL-L2 netlab KNE deployments must use startup config and avoid IOS Ansible privilege-escalation failures.

## Demo reset durability

Root causes found:

- The nightly reset job did run, but reset tasks serialized on the global Forward demo reset lock.
- Reset tasks inherited generic queue behavior: 30 minute queue TTL and 8 capacity retries.
- Later users could expire before acquiring the reset lock, leaving stale demo orgs.
- Worker restarts could leave reset rows active/running long enough to block later cron attempts.
- The seed repair check accepted one processed snapshot as "seeded", which allowed partially populated demo orgs to pass.
- Service/non-shareable accounts could enter the demo reset bootstrap path and consume the same global lock.

Code changes:

- `components/server/skyforge/cron_forward_demo_org_reset.go`
  - default nightly/seed-repair batch size is now unbounded (`0`), not capped at 10.
- `components/server/skyforge/forward_tenant_reset_task_queue.go`
  - demo reset tasks now use a 6 hour queue TTL and 72 capacity retries.
  - metadata records `queueTTLSeconds`, `capacityRetryMax`, and `capacityRetryMode`.
- `components/server/internal/taskexec/queued_task_retry.go`
  - queue retry logic honors per-task `capacityRetryMax`.
  - Forward reset retryable lock errors fall back to 72 attempts.
- `components/server/skyforge/forward_tenant_reset_reconcile.go`
  - stale active reset runs are marked failed after the configured active window.
- `components/server/skyforge/forward_demo_seed_autofix.go`
  - seed repair now verifies the expected processed seed count instead of accepting a single latest processed snapshot.
- `components/server/skyforge/forward_worker_api.go`
  - non-shareable users return early from tenant bootstrap to avoid service accounts entering demo seed/reset work.

Operational verification commands:

```bash
KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge get cronjob skyforge-forward-demo-reset skyforge-forward-demo-org-seed-repair

KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge exec deploy/db -- \
  psql -U skyforge_server -d skyforge_server -P pager=off -c "
select t.id,t.status,r.username,r.status as run_status,r.updated_at,t.started_at,t.finished_at,
       t.metadata->>'capacityRetryMax' as retry_max,
       t.metadata->>'queueExpiresAt' as queue_expires,
       t.metadata->>'capacityRetryCount' as retry_count,
       t.metadata->>'capacityRetryAt' as retry_at,
       left(coalesce(t.error,''),100) as err
from sf_tasks t
left join sf_forward_tenant_reset_runs r on r.id::text = t.metadata->'spec'->>'runId'
where t.task_type='forward-tenant-reset' and t.created_at > now() - interval '180 minutes'
order by t.created_at desc;"
```

Manual cron rerun:

```bash
JOB=skyforge-forward-demo-reset-manual-$(date +%Y%m%d%H%M%S)
KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge create job --from=cronjob/skyforge-forward-demo-reset "$JOB"
KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge wait --for=condition=complete job/"$JOB" --timeout=30m
KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge logs job/"$JOB" --timestamps=true
```

Readiness query:

```bash
KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge exec deploy/db -- \
  psql -U skyforge_server -d skyforge_server -P pager=off -c "
select distinct on (username)
  username,status,created_at,updated_at,
  metadata_json->>'lastStep' as last_step,
  left(coalesce(metadata_json->>'lastError',''),120) as last_error,
  metadata_json->>'demoSeedUploadedSeedCount' as uploaded_seed_count,
  metadata_json->>'demoSeedProgressProcessed' as processed_seed_count,
  metadata_json->>'demoSeedProcessedSnapshot' as processed_snapshot
from sf_forward_tenant_reset_runs
where tenant_kind='demo'
order by username, created_at desc;"
```

## Quick Deploy catalog behavior

Quick Deploy is intentionally simple in the UI:

- Users select tags and templates.
- It does not expose a free-form repo picker.
- Eligible public Skyforge Gitea source repos are discovered automatically.
- Public repo templates are included when they are KNE-compatible and live under either `netlab/` or `labs/`.
- Training labs come from `craigjohnson/skyforge-training/labs` and are tagged `training`, `public`, and `forward-sync`.

Code changes:

- `components/server/skyforge/quick_deploy_catalog_public.go`
  - discovers public Gitea source repos and scans eligible template directories.
- `components/server/skyforge/quick_deploy_catalog_runtime.go`
  - appends public repo templates to stored/default catalog entries.
- `components/server/skyforge/quick_deploy_run.go`
  - carries `templateSource`, `templateRepo`, and `templatesDir` through deployment.
  - verifies custom/public templates are actually public and KNE-compatible.
- `components/server/skyforge/quick_deploy_catalog_settings.go`
- `components/server/skyforge/quick_deploy_catalog_validation.go`
- `components/server/skyforge/quick_deploy_estimate.go`
- `components/server/skyforge/quick_deploy_helpers.go`
- Portal Quick Deploy code removes arbitrary repo selection and renders catalog entries only.

Prod catalog verification used:

```bash
curl -fsS -H "Cookie: <skyforge session>" https://skyforge.dc.forwardnetworks.com/api/quick-deploy/catalog
```

Expected result after the fix:

- catalog includes stored/default labs and public Gitea labs.
- `training` tag has entries from `craigjohnson/skyforge-training`.
- public entries carry `templateSource=custom`, `templateRepo=<owner>/<repo>`, and `templatesDir=labs` or `netlab`.

## IOL startup mode and privilege escalation

Do not edit individual training topologies to force behavior. Configure via netlab defaults/runtime:

- `components/server/netlab/runtime/defaults.yml`
  - IOL/IOL-L2 use `netlab_config_mode: startup`.
- `components/server/netlab/runtime/netlab.py`
  - when a topology is mixed, `netlab initial` is limited to generated-day0 nodes only.
  - startup-config nodes are excluded from Ansible `ios_config` pushes.

Validation pattern:

```bash
KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge logs deploy/skyforge-server-worker --since=60m | rg "netlab initial args|deploy-config/ios.yml|operation requires privilege escalation"
```

Expected result for mixed IOL/EOS training labs:

- `netlab initial args` includes `--limit` with non-IOL/generated-day0 nodes only.
- IOL nodes do not appear under `deploy-config/ios.yml`.
- No `operation requires privilege escalation` errors.

Known validated run:

- deployment: `ea88f8f6-9001-4957-958c-febd6c05c008`
- name: `codex-verify-training-lab01-iol-startup`
- template repo: `craigjohnson/skyforge-training`
- template dir: `labs`
- template: `lab01-foundations/topology.yml`
- task `3209` succeeded and logged `netlab initial args: --fast --limit core1,core2,dist2`
- Forward sync task `3210` started and uploaded 6 devices for network `399`.

## Images

Netlab image:

- `ghcr.io/forwardnetworks/skyforge-netlab:20260427-iol-startup-limit-r1`

Server/worker images built for the durable cron + quick deploy changes:

- `ghcr.io/forwardnetworks/skyforge-server:20260427-quickdeploy-cronfix-r4`
- `ghcr.io/forwardnetworks/skyforge-server:20260427-quickdeploy-cronfix-r4-worker`

Deploy command:

```bash
SKYFORGE_ALLOW_PROD_DEPLOY=true \
SKYFORGE_SERVER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:20260427-quickdeploy-cronfix-r4 \
SKYFORGE_SERVER_WORKER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:20260427-quickdeploy-cronfix-r4-worker \
SKYFORGE_NETLAB_IMAGE=ghcr.io/forwardnetworks/skyforge-netlab:20260427-iol-startup-limit-r1 \
./scripts/deploy-skyforge-env.sh prod
```

Restore path:

- redeploy the previous server/worker images with the same command and prior image refs.
- leave the netlab image pinned to `20260427-iol-startup-limit-r1`; that image is the fix for IOL startup-mode privilege escalation.
