# ServiceNow: Forward Connectivity Ticket Demo

Skyforge can install a small ServiceNow “Connectivity Ticket” demo app into a ServiceNow Developer Instance (PDI).

The demo app:
- collects `srcIp/dstIp/protocol/port` from a Service Portal widget
- calls Forward Path Search (`GET /api/networks/{networkId}/paths`)
- normalizes the result into allowed/blocked + a hop trace
- stores hop records on the ticket

## Prerequisites

- A ServiceNow Personal Developer Instance (PDI)
- Forward SaaS credentials (for `https://fwd.app`)

## Setup

1) Create a ServiceNow PDI.
2) In Skyforge, open **ServiceNow** (left navigation).
3) Enter:
   - ServiceNow instance URL (your PDI URL)
   - ServiceNow admin username/password
   - Forward base URL: `https://fwd.app/api`
   - Forward username/password
4) Click **Save**.
5) Click **Install demo app**.

## Notes

- ServiceNow calls Forward SaaS directly. Skyforge is only used to install/configure the ServiceNow artifacts.
- The installer uses ServiceNow’s Table API to create/update records and will overwrite demo artifact contents by name (tables, fields, scripts, widget, REST message).
