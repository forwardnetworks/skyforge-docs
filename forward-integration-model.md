# Skyforge Forward Integration Model

This document describes the current managed Forward model in Skyforge.

## Managed orgs per user

Skyforge now manages two Forward org credentials per user:

- `primary`
  - deployment-backed org
  - used for managed collector lifecycle
  - used for deployment sync
  - used for network-targeted Forward launch flows
- `demo`
  - isolated demo org
  - not used for deployment sync
  - does not require a managed collector
  - default target for the generic Forward launch button

Both orgs are provisioned from the platform-managed Forward tenant flow. The
demo org uses a distinct Forward username and org name suffix to avoid relying
on org-scoped usernames.

## UI behavior

Forward navigation now exposes two managed-org entry points:

- `Demo Org`
- `Deployment Org`

The generic Forward launch action opens the `demo` org by default. Deployment
and network-specific actions remain pinned to the `primary` org.

The `Forward Org Access` page now shows both managed orgs separately:

- demo org credential, reset, and synthetic performance controls
- deployment org credential, feature flags, synthetic performance controls, and
  rebuild controls

Saved external Forward credential sets remain separate from the managed-org
credentials.

## Deployment sync modes

Deployment Forward sync now supports two explicit modes:

- `full` (default)
  - syncs topology devices into Forward
  - starts collection and records the latest processed snapshot for the deployment
- `metadata-only`
  - syncs topology devices into Forward
  - does **not** start collection
  - intended for unconfigured labs where operators want network/source objects
    created first without device login assumptions

API surface:

- `POST /api/users/:id/deployments/:deploymentID/forward/sync`
  - request body: `{ "mode": "full" | "metadata-only" }`
  - omitting `mode` is equivalent to `"full"`

## Reset behavior

Deployment-org resets preserve the existing managed behavior:

- managed collector state is torn down and recreated as needed
- deployment sync state is cleared and rebound
- managed deployment baselines are restored and resynced

Demo-org resets are isolated from deployment state:

- they do not clear deployment Forward sync state
- they do not tear down managed collector state
- they destroy and recreate the demo org when a curated or hard reset runs
- they replay the admin-managed demo seed catalog into a single network named
  `Demo Network`
- manual resets wait for the final seeded snapshot to process, then attempt
  synthetic performance generation
- nightly resets run in upload-only mode: they submit every seed but do not
  wait for Forward processing to finish before marking the reset complete
- demo resets only transition to `ready` after Skyforge can verify that the
  recreated demo org still has a processed snapshot in `Demo Network`
- they rotate the demo-org credential whenever the org is recreated

This separation is required so a demo-org reset cannot damage the active
deployment-backed org.

## Demo-org bootstrap and repair

Demo-org credential provisioning and demo snapshot seeding are intentionally
separate operations:

- first-login bootstrap ensures both managed-org credentials exist
- demo seeding is still performed by the curated demo reset workflow

To keep those paths aligned, Skyforge now auto-queues the curated demo reset
when it detects that a user's demo org exists but does not yet have a processed
snapshot in `Demo Network`.

That repair path currently runs from:

- the worker-backed `user-bootstrap` flow for new users
- demo-org credential/reveal/reset access paths as a best-effort self-heal
- a dedicated background repair cron for already-known users

This means a user can receive demo credentials immediately, while Skyforge
still converges the org onto the same seeded state used by manual and nightly
demo rebuilds.

## Synthetic performance generation

Skyforge exposes synthetic performance generation through explicit managed-org controls.

For each managed org, the UI lists the visible Forward networks, resolves the
latest processed snapshot when available, and calls the internal Forward API:

- `POST /api/internal/networks/<networkId>/performance`
  - `op=generate`
  - `snapshotId=<snapshotId>`
  - `generationIntervalMins=10`
  - `healthyDeviceOdds=0.8`
  - `healthyInterfaceOdds=0.8`

Managed-org API surfaces:

- deployment org
  - `GET /api/forward/org/performance-networks`
  - `POST /api/forward/org/performance-networks/:networkID/generate`
  - deployment sync does **not** auto-generate synthetic performance
- demo org
  - `GET /api/forward/demo-org/performance-networks`
  - `POST /api/forward/demo-org/performance-networks/:networkID/generate`

## Demo seed catalog

Skyforge now supports an admin-managed demo seed catalog:

- admins upload one or more snapshot zip archives
- each seed has a Forward snapshot `note`, an enable flag, and replay order
- the catalog also stores a single demo `networkName`
- nightly and manual demo rebuilds use the same ordered seed list
- all enabled seeds replay into the same demo network in order

Admin API surfaces:

- `GET /api/admin/integrations/forward/demo-seeds`
- `POST /api/admin/integrations/forward/demo-seeds`
- `PATCH /api/admin/integrations/forward/demo-seeds/:seedID`
- `DELETE /api/admin/integrations/forward/demo-seeds/:seedID`

The seed archives are stored in the configured object store, while seed catalog
metadata is stored in settings.

## Nightly rebuilds

Skyforge queues a daily demo-org curated reset for known users. That nightly
workflow:

1. destroys and recreates the demo org
2. creates the configured demo network name (default `Demo Network`)
3. uploads each enabled seed archive in order
4. records upload metrics and the last submitted snapshot id in reset metadata
5. does not wait for Forward snapshot processing to finish
6. does not trigger synthetic performance generation
7. forces the demo org back to stock feature flags with experimental features off

This keeps the nightly runner from getting stuck behind long-running Forward
processing while still preserving reset telemetry. Manual resets can still use
the stricter wait-for-processing path when that feedback is useful.

In self-managed deployments, that nightly trigger is chart-managed as the
Kubernetes CronJob `skyforge-forward-demo-reset`. The job prefers a Skyforge API
token against the in-cluster Skyforge API URL and falls back to the configured
admin credentials when the token is not present. It queues the same
platform-managed demo reset workflow used by the admin UI. The optional token is
stored in the configured Kubernetes secret (default `skyforge-admin-shared` key
`api-token`).

Separate from the nightly rebuild, Skyforge also runs a lighter-weight
demo-seed repair cron. That repair loop only queues curated demo resets for
users whose demo orgs are missing the seeded `Demo Network` snapshot, which
lets existing empty demo orgs converge without waiting for the nightly rebuild.

For multi-user demo environments with replayed seed catalogs, the worker
deployment should not stay at the smallest background defaults. The chart now
defaults to a larger background runner queue, and the local production values
run two worker replicas so nightly resets can drain while seed replay and
collector follow-up tasks are in flight.

Because the org is recreated, demo-org credentials are ephemeral and rotate on
nightly rebuilds. Users should rely on the session bridge or the reveal/copy
controls in `Forward Org Access` for the current demo credential.

## Forward AI runtime split

Forward AI is intentionally split across two runtime paths in this deployment:

- `fwd-appserver`
  - keeps direct Bedrock access for the NQE generator path
  - should not run with the `ON_PREM` profile when AI features are needed
- `fwd-baml-server`
  - owns chat orchestration and model routing for Forward AI chats

This means `appserver.ai_bedrock.*` is still required for NQE generation, but
the live BAML bundle remains the source of truth for Sonnet-vs-Haiku routing in
the chat flow.

`fwd-nqe-assist` has its own runtime secret contract and should not be treated
as a clone of `appserver.ai_bedrock.secret_name`. The Harbor `fwd_nqe_assist`
image expects the mounted `fwd-app-creds-for-nqe-assist` secret to carry at
least:

- `FWD_API_ACCESS_KEY`
- `FWD_API_SECRET_KEY`
- `MODEL_INSTANCE_URL`
- `QUERY_ASSIST_ADAPTER_ID`

plus any additional model/runtime credentials required by the shipped image.
Skyforge local bootstrap now treats that secret as a separate precreated input;
operators may optionally sync it from another secret via
`SKYFORGE_FORWARD_NQE_ASSIST_SOURCE_SECRET_NAME`, but it is no longer derived
from `forward-aws-credentials` by default.

Skyforge deployment automation now supports an explicit
`skyforge.forwardCluster.appserverProfiles` value. In the local production
values this is pinned to `K8S`, which is the correct self-managed profile for
the current AI-enabled Forward deployment.
