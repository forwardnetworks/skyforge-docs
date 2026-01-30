# ServiceNow: Forward Connectivity Ticket Demo

Skyforge can install a small ServiceNow “Connectivity Ticket” demo app into a ServiceNow Developer Instance (PDI).

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
2) In Skyforge, open **ServiceNow** (left navigation).
3) Enter / confirm:
   - ServiceNow instance URL (your PDI URL)
   - ServiceNow admin username/password
   - Forward credentials:
     - select a collector (recommended), or
     - choose **Custom…** and enter username/password.
4) Click **Save**.
5) (Optional) If your PDI is sleeping, use **PDI status → Wake up**.
6) Create the demo schema (manual step):
   - Create tables:
     - `x_fwd_demo_connectivity_ticket`
     - `x_fwd_demo_connectivity_hop`
   - Create fields listed in **ServiceNow → Schema status** (Skyforge will tell you what’s missing).
7) Click **Install demo app** (installs scripts, REST message, portal widget, and properties).
7) (Optional) Click **Configure Forward (ticketing)** to configure Forward’s ServiceNow ticketing integration (auto-create/update incidents).

## Notes

- ServiceNow calls Forward SaaS directly. Skyforge is only used to install/configure the ServiceNow artifacts.
- Skyforge installs scripts/widgets/etc via ServiceNow’s Table API, but **does not create the schema** (custom tables/fields). Some ServiceNow instances block schema creation via Table API.
- The installer overwrites demo artifact contents by name (scripts, widget, REST message, properties).
