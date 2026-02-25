# Executive Deploy Workflow

This page adds a simplified deployment path at `/dashboard/deployments/executive`.

## Scope

- Deployment type: `netlab-c9s` only.
- Template source: curated Netlab blueprints under `netlab/_e2e`.
- Forward: requires a selected Forward credential profile (`/api/forward/collector-configs`).
- Lease presets: `2h`, `4h`, `8h`.

## Flow

1. User selects a curated template.
2. User selects an existing Forward credential profile or creates one inline.
3. Skyforge creates a `netlab-c9s` deployment with `forwardEnabled=true`.
4. Skyforge writes deployment lease metadata via
   `PUT /api/users/:id/deployments/:deploymentID/lease`.
5. Skyforge queues deployment create action.

## Lease enforcement

- Lease metadata is stored in deployment config keys:
  - `executiveLeaseEnabled`
  - `executiveLeaseHours`
  - `executiveLeaseExpiresAt`
  - `executiveLeaseStoppedAt`
  - `executiveLeaseStopTaskId`
- Cron job `skyforge-executive-deployment-leases` runs every 5 minutes.
- For expired leases, Skyforge queues a netlab-c9s destroy action and stamps
  `executiveLeaseStoppedAt` + `executiveLeaseStopTaskId`.

## APIs

- `GET /api/users/:id/deployments/:deploymentID/lease`
- `PUT /api/users/:id/deployments/:deploymentID/lease`
- `POST /internal/cron/deployments/executive-leases` (private cron endpoint)
