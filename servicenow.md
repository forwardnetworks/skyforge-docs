# ServiceNow: Forward Connectivity Ticket Demo

Skyforge provides a near-zero-touch workflow for a shared ServiceNow PDI with
per-user tenant isolation.

The demo app:
- collects `srcIp/dstIp/protocol/port` from a Service Portal widget
- calls Forward Path Search (`GET /api/networks/{networkId}/paths`)
- normalizes the result into allowed/blocked + a hop trace
- stores hop records on the ticket

## Model

- One global ServiceNow PDI is configured by Skyforge admins.
- Each Skyforge user maps to a dedicated ServiceNow tenant user.
- Each user is bound to their managed Skyforge Forward org credential.
- Runtime operations are server-scoped to the authenticated Skyforge user.

## Prerequisites

- A ServiceNow Personal Developer Instance (PDI)
- Skyforge Forward tenant provisioning enabled for the user.

## Setup

1) Admin: open **Settings → Users & Access** and configure:
   - ServiceNow instance URL
   - ServiceNow admin username/password
2) Admin: click **Install shared app assets** once after global settings are saved.
3) User: open **ServiceNow**.
4) Click **Save tenant binding**.
5) Click **Run setup**.
6) If setup pauses at `needs_manual_step`, apply remediation shown in the UI and click **Resume setup**.

## Tenant Operations

- **Reset tenant password** rotates the mapped ServiceNow user password and
  reprovisions the tenant user.
- Forward ticketing integration is configured using the user's managed Forward
  org credential plus tenant ServiceNow credentials, not the global ServiceNow
  admin account.

## Reachability Gate

- `fwd.app` uses a fast path and skips the extra reachability gate.
- On-prem/custom Forward hosts must be reachable from the ServiceNow runtime.
- Skyforge validates this by running a ServiceNow-side probe after installation.
- If unreachable, setup returns remediation steps (DNS/routing/firewall/TLS trust).

## Notes

- ServiceNow calls the user's managed Forward org endpoint directly.
- Skyforge attempts to create the required schema and assets via ServiceNow Table API.
- If the ServiceNow instance blocks table creation, setup reports exact manual steps and supports resume.
- The installer overwrites demo artifact contents by name (scripts, widget, tables, and properties).
- Forward username/password are stored in a per-tenant ServiceNow binding
  record, not in global sys_properties, so one user's setup does not overwrite
  another user's binding in the shared PDI.
- Skyforge runs an Encore-native keepalive cron for the global PDI (`/internal/cron/servicenow/pdi/keepalive`) every 20 minutes to reduce demo interruptions from PDI sleep/hibernation.

## Demo Asset Source-Of-Truth

Skyforge consumes ServiceNow demo assets from:

- `https://github.com/forwardnetworks/forward-servicenow-demo`

Use the sync helper from the Skyforge repo root:

```bash
# Check-only: fail if local Skyforge assets drift from source repo.
./scripts/sync-servicenow-demo-assets.sh --check-only

# Write mode: copy source files into Skyforge and update source metadata.
./scripts/sync-servicenow-demo-assets.sh --write
```

Defaults:

- source repo path: `~/src/forward-servicenow-demo`
- metadata file: `components/server/skyforge/servicenow_demo_version.txt`
