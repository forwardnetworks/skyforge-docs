# Quick Deploy Workflow

This page documents the simplified deployment path at `/dashboard/deployments/quick`.

## Scope

- Deployment type: `netlab-c9s` only.
- Template source: curated Netlab blueprints under `netlab/_e2e`.
- Forward: always uses in-app Forward (`http://fwd-appserver.forward.svc.cluster.local:8080`)
  with managed credentials from platform secrets.
  - `skyforge-quick-deploy-forward-username.skyforge-quick-deploy-forward-username`
  - `skyforge-quick-deploy-forward-password.skyforge-quick-deploy-forward-password`
- Lease presets: `4h`, `8h`, `24h`, `72h` (default `24h`).

## Flow

1. User selects a curated template card.
2. Skyforge upserts a managed Forward credential profile (`quick-deploy-in-cluster`)
   for the current user.
3. Skyforge creates a `netlab-c9s` deployment with `forwardEnabled=true`.
4. Skyforge writes deployment lease metadata via
   `PUT /api/users/:id/deployments/:deploymentID/lease`.
5. Skyforge preflights and queues deployment create action.

## Lease enforcement

- Lease metadata is stored in deployment config keys:
  - `leaseEnabled`
  - `leaseHours`
  - `leaseExpiresAt`
  - `leaseStoppedAt`
  - `leaseStopTaskId`
- Cron job `skyforge-deployment-leases` runs every 5 minutes.
- For expired leases, Skyforge queues a netlab-c9s stop action and stamps
  `leaseStoppedAt` + `leaseStopTaskId`.

## Regular deployments

- The regular Deployments page (`/dashboard/deployments`) exposes per-deployment
  lifetime management for managed types (`netlab-c9s`, `clabernetes`,
  `terraform`).
- Non-admin users cannot disable lifetime expiry and are capped at `72h`.
- Admin users can select "No expiry".

## APIs

- `GET /api/users/:id/deployments/:deploymentID/lease`
- `PUT /api/users/:id/deployments/:deploymentID/lease`
- `GET /api/deployment-lifetime/policy`
- `GET /api/quick-deploy/catalog`
- `POST /api/quick-deploy/deploy`
- `POST /internal/cron/deployments/leases` (private cron endpoint)
