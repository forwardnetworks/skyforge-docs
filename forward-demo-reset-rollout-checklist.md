# Forward Demo Reset Rollout Checklist

This runbook covers the next rollout that includes:

- stale active demo-reset auto-clear in `components/server/platform/store_forward_resets.go`
- Git-backed demo seed catalog support in Skyforge
- local worker controller override for Forward compute/search workers

It is intentionally focused on proving that the nightly demo-org reset is no longer permanently blocked by abandoned reset rows.

## Current known live issue

As of `2026-04-02`, the nightly cron is still firing, but some users have demo reset rows stuck in `reprovisioning` since `2026-03-31`. Those rows block later nightly/manual resets because the platform store currently treats them as active forever.

Known stuck users before rollout:

- `craigjohnson`
- `garyberger`
- `rudycollado`

Known successful nightly resets after March 31:

- `glenturner`
- `kevinkuhls`

This confirms the defect is per-user stale state, not a globally dead cronjob.

## Pre-rollout evidence capture

Capture the currently stuck rows before deploying so post-rollout behavior is easy to compare.

```bash
kubectl -n skyforge exec deploy/db -- \
  psql -U skyforge_server -d skyforge_server -P pager=off -c "
select
  id,
  username,
  tenant_kind,
  status,
  created_at,
  updated_at,
  metadata_json->>'lastStep' as last_step,
  metadata_json->>'lastError' as last_error
from sf_forward_tenant_reset_runs
where username in ('craigjohnson','garyberger','rudycollado')
  and tenant_kind='demo'
order by updated_at desc;"
```

Capture all currently active demo-reset rows:

```bash
kubectl -n skyforge exec deploy/db -- \
  psql -U skyforge_server -d skyforge_server -P pager=off -c "
select
  username,
  tenant_kind,
  count(*) filter (
    where status in ('requested','draining','deleting','reprovisioning','validating')
  ) as active_runs,
  min(updated_at) filter (
    where status in ('requested','draining','deleting','reprovisioning','validating')
  ) as oldest_active,
  max(updated_at) filter (
    where status in ('requested','draining','deleting','reprovisioning','validating')
  ) as newest_active
from sf_forward_tenant_reset_runs
group by username, tenant_kind
having count(*) filter (
  where status in ('requested','draining','deleting','reprovisioning','validating')
) > 0
order by oldest_active asc;"
```

## Rollout contents to include

Recommended rollout contents:

1. stale reset auto-clear fix
2. local Forward worker override (`use_deployment_for_workers: true`)
3. Git-backed demo seed catalog work

The stale reset fix is the blocker for nightly progress. The other two improve runtime stability and seed management but are not substitutes for the stale-row fix.

## Recommended commit / rollout order

Keep the rollout package in this order so the risk is easier to reason about:

1. `components/server`
   - stale active reset auto-clear
   - Git-backed demo seed catalog server support
2. `components/blueprints`
   - `forward/demo-seeds/catalog.yaml`
   - `forward/demo-seeds/assets/*.zip`
   - `.gitattributes` for ZIP tracking
3. local Skyforge rollout overlays/scripts
   - Forward compute/search worker override
   - demo-fast overlay cleanup
4. `components/docs`
   - this runbook
   - local overlay usage docs

If you split commits, keep server/platform logic independent from the rollout-overlay change so the nightly reset fix can be reasoned about separately from Forward worker behavior.

## Immediate post-rollout checks

### 1. Verify server version is live

Check the `skyforge-server` pod restart time and image tag in the rollout window.

```bash
kubectl -n skyforge get deploy skyforge-server skyforge-server-worker -o wide
```

### 2. Verify the old stuck rows are no longer terminal blockers

The next reset request for a stuck user should auto-fail any stale active row older than the stale window and allow a new run to be created.

Use the UI or API to request a manual demo rebuild for:

- `craigjohnson`

Then confirm that:

- the old March 31 row is now `failed`
- `metadata_json->>'lastStep' = 'stale-clear'`
- `metadata_json->>'lastError'` explains that the stale active run was automatically cleared
- a newer run exists for the same user

DB query:

```bash
kubectl -n skyforge exec deploy/db -- \
  psql -U skyforge_server -d skyforge_server -P pager=off -c "
select
  id,
  username,
  tenant_kind,
  status,
  created_at,
  updated_at,
  metadata_json->>'lastStep' as last_step,
  metadata_json->>'lastError' as last_error
from sf_forward_tenant_reset_runs
where username='craigjohnson'
  and tenant_kind='demo'
order by created_at desc
limit 10;"
```

### 3. Verify run progression for the new request

Expected happy-path state progression:

- `requested`
- `draining`
- `deleting`
- `reprovisioning`
- `validating`
- `ready`

If it fails, `lastStep` and `lastError` must be populated.

## Nightly cron verification

After the next scheduled run (`03:17 America/Chicago`), confirm the cron created fresh demo reset runs instead of skipping blocked users.

Check cronjob schedule evidence:

```bash
kubectl -n skyforge describe cronjob skyforge-forward-demo-reset
```

Check newly created demo reset runs:

```bash
kubectl -n skyforge exec deploy/db -- \
  psql -U skyforge_server -d skyforge_server -P pager=off -c "
select
  username,
  tenant_kind,
  status,
  created_at,
  updated_at,
  metadata_json->>'lastStep' as last_step,
  metadata_json->>'lastError' as last_error
from sf_forward_tenant_reset_runs
where tenant_kind='demo'
  and created_at >= now() - interval '24 hours'
order by created_at desc;"
```

## Demo seed catalog checks

### Important rollout note

The currently deployed admin endpoint still serves the legacy uploaded demo seed catalog. The Git-backed demo seed catalog code will not be visible until after the rollout.

The Git-backed seed assets staged for this rollout are:

1. `Pre-Change`
   - `forward/demo-seeds/assets/DemoFoundry-1.3.2-Pre-Change Snapshot.zip`
   - sha256: `f5d922ff0a3e9e76b39ef5936026c46d53cce8417b2c3c1fcad366e583c74b0a`
2. `Post-Change`
   - `forward/demo-seeds/assets/DemoFoundry-1.3.2-After Change.zip`
   - sha256: `8c5a01a05b3d446af3f10bcc30e5f4daf7a9b9179aa27bc403617220e79d5564`

Before rollout, confirm what the live system thinks the catalog is:

```bash
TOKEN=$(kubectl -n skyforge get secret skyforge-admin-shared -o jsonpath='{.data.api-token}' | base64 -d)
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://skyforge.local.forwardnetworks.com/api/admin/integrations/forward/demo-seeds | python3 -m json.tool
```

After rollout, that endpoint should reflect the Git-backed catalog shape:

- `source = gitea`
- `repo`
- `branch`
- `manifestPath`
- `manifestValid`
- `lastCommitSha`

If the rollout includes the Git-backed catalog, verify:

1. the manifest loads successfully
2. every expected seed entry is present
3. the replay order is correct
4. duplicate entries are preserved if intentionally configured

If the rollout includes the blueprints ZIPs, ensure the push path handles large files correctly. The repo now includes `.gitattributes` for LFS tracking, but the local shell used for staging did not have `git lfs` installed. Confirm the actual commit/push environment writes the ZIPs through your intended Git/LFS path.

## Worker stabilization checks

If the rollout includes the local worker override, verify compute/search workers are rendered as `Deployment` workloads, not `StatefulSet`.

```bash
kubectl -n forward get deploy,statefulset | rg 'fwd-(compute-worker|search-worker)'
```

Expected:

- `Deployment/fwd-compute-worker`
- `Deployment/fwd-search-worker`
- no matching StatefulSets for those workers

Then check for absence of recent Longhorn multi-attach churn:

```bash
kubectl -n forward get events --sort-by=.lastTimestamp | \
  rg 'Multi-Attach|FailedAttachVolume|fwd-compute-worker|fwd-search-worker'
```

## Success criteria

The rollout is successful if all of the following are true:

1. a previously blocked user can create a new demo reset run
2. the old stale run is automatically marked `failed` with `lastStep=stale-clear`
3. the new run reaches `ready` or, if it fails, records a clear `lastStep` and `lastError`
4. the next nightly cron produces fresh demo reset runs instead of being blocked by March 31 rows
5. if included, the new Git-backed demo seed catalog is visible and valid
6. if included, Forward compute/search workers run as `Deployment` and stop flapping on RWO scratch PVC reattachment

## Known remaining risks

- Seed replay can still fail for reasons unrelated to stale reset rows:
  - missing seed object
  - snapshot processing failure
  - Forward timeout during replay or synthetic performance generation
- The stale-row fix only ensures those failures do not permanently block all future resets for the same user.
