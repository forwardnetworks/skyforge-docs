# Quick Deploy Workflow

This page documents the simplified deployment path at `/dashboard/deployments/quick`.

## Scope

- Deployment family/engine: `kne` / `netlab` only.
- Template source: curated Netlab blueprints managed by an admin catalog.
  - Default catalog focuses on EOS technology demos (EVPN, MPLS, BGP, VRF).
  - Default template files map to `netlab/*/topology.yml` from `skyforge/blueprints`.
  - Admin catalog saves are validated against live blueprint template index entries to prevent drift.
- Forward: always uses in-app Forward (`https://fwd-appserver.forward.svc.cluster.local`)
  with per-user tenant credentials + API token.
  - Skyforge ensures the user has a Forward org user/password.
  - Skyforge ensures API token `skyforge` exists for that user.
  - Token `accessKey` + `secret` are stored as the managed in-cluster collector
    credential for that user.
- Lease presets: `4h`, `8h`, `24h`, `72h` (default `24h`).

## Flow

1. User selects a curated template card.
2. Skyforge upserts a managed Forward credential profile (`in-cluster forward`)
   for the current user from token `skyforge`.
3. Skyforge creates a deployment with family/engine `kne` / `netlab` and
   `forwardEnabled=true`.
4. Skyforge writes deployment lease metadata via
   `PUT /api/users/:id/deployments/:deploymentID/lease`.
5. Skyforge queues deployment create action directly (with short retry on
   transient duplicate/cooldown no-op responses).

## Lease enforcement

- Lease metadata is stored in deployment config keys:
  - `leaseEnabled`
  - `leaseHours`
  - `leaseExpiresAt`
  - `leaseStoppedAt`
  - `leaseStopTaskId`
- Cron job `skyforge-deployment-leases` runs every 5 minutes.
- For expired leases, Skyforge queues a `kne/netlab` stop action and stamps
  `leaseStoppedAt` + `leaseStopTaskId`.

## Regular deployments

- The regular Deployments page (`/dashboard/deployments`) exposes per-deployment
  lifetime management for managed deployment families (`kne`, `terraform`).
- Non-admin users cannot disable lifetime expiry and are capped at `72h`.
- Admin users can select "No expiry".

## APIs

- `GET /api/users/:id/deployments/:deploymentID/lease`
- `PUT /api/users/:id/deployments/:deploymentID/lease`
- `GET /api/deployment-lifetime/policy`
- `GET /api/quick-deploy/catalog`
- `POST /api/quick-deploy/deploy`
- `GET /api/admin/quick-deploy/catalog`
- `PUT /api/admin/quick-deploy/catalog`
- `GET /api/admin/quick-deploy/template-options`
- `POST /internal/cron/deployments/leases` (private cron endpoint)
