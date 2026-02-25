# ServiceNow: Forward Connectivity Ticket Demo

Skyforge provides a near-zero-touch setup workflow for installing the ServiceNow
“Connectivity Ticket” demo app.

The demo app:
- collects `srcIp/dstIp/protocol/port` from a Service Portal widget
- calls Forward Path Search (`GET /api/networks/{networkId}/paths`)
- normalizes the result into allowed/blocked + a hop trace
- stores hop records on the ticket

## Prerequisites

- A ServiceNow Personal Developer Instance (PDI)
- Forward SaaS credentials (for `https://fwd.app`) via either:
  - a Skyforge Forward collector (recommended), or
  - manual username/password.

## Setup

1) Create a ServiceNow PDI.
2) In Skyforge, open **ServiceNow**.
3) Set:
   - ServiceNow instance URL
   - ServiceNow admin username/password
   - Forward credential set (from **Forward → Credentials**)
4) Click **Save settings**.
5) Click **Run setup**.
6) If setup pauses at `needs_manual_step`, apply remediation shown in the UI and click **Resume setup**.

## Reachability Gate

- `fwd.app` uses a fast path and skips the extra reachability gate.
- On-prem/custom Forward hosts must be reachable from the ServiceNow runtime.
- Skyforge validates this by running a ServiceNow-side probe after installation.
- If unreachable, setup returns remediation steps (DNS/routing/firewall/TLS trust).

## Notes

- ServiceNow calls the selected Forward host directly.
- Skyforge attempts to create the required schema and assets via ServiceNow Table API.
- If the ServiceNow instance blocks table creation, setup reports exact manual steps and supports resume.
- The installer overwrites demo artifact contents by name (scripts, widget, REST message, properties).
