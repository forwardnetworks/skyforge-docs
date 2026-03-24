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
- they generate synthetic performance data after the final seeded snapshot is
  processed
- they rotate the demo-org credential whenever the org is recreated

This separation is required so a demo-org reset cannot damage the active
deployment-backed org.

## Synthetic performance generation

Skyforge exposes synthetic performance generation for both managed orgs.

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
- demo org
  - `GET /api/forward/demo-org/performance-networks`
  - `POST /api/forward/demo-org/performance-networks/:networkID/generate`

## Demo seed catalog

Skyforge now supports an admin-managed demo seed catalog:

- admins upload one or more snapshot zip archives
- each seed has an enable flag and replay order
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
2. creates `Demo Network`
3. uploads each enabled seed archive in order
4. waits for the final snapshot to process
5. generates synthetic performance data

Because the org is recreated, demo-org credentials are ephemeral and rotate on
nightly rebuilds. Users should rely on the session bridge or the reveal/copy
controls in `Forward Org Access` for the current demo credential.
