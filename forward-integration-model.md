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
- they only rotate or reprovision the demo org itself

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

## Current boundary

Skyforge now has the dual-org control-plane split, tenant-safe reset behavior,
and per-org synthetic performance controls. It does not yet have a built-in
curated demo data seed source that can recreate a non-empty demo org after a
hard reset.

That matters because a true daily curated demo reset requires a replayable demo
dataset or an import/clone workflow from Forward. The local Forward API wrapper
currently covers:

- org and user provisioning
- network creation and deletion
- device and credential upsert
- collection control
- synthetic performance generation

It does not yet include a supported export/import or org-clone path for demo
content reseeding.

Until a seed source is defined, the implemented demo-org reset behavior is
limited to safe reprovisioning and credential isolation, not curated dataset
replay.
