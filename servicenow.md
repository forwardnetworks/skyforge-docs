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
3) (Optional) Create a local env file (not uploaded) to speed up setup:

```bash
cat > servicenow-pdi.env <<'EOF'
# ServiceNow PDI
SN_INSTANCE_URL=https://dev12345.service-now.com
SN_ADMIN_USERNAME=admin
SN_ADMIN_PASSWORD=REPLACE_ME

# Forward SaaS
FWD_BASE_URL=https://fwd.app/api
FWD_USERNAME=you@example.com
FWD_PASSWORD=REPLACE_ME
EOF
```

Then import it in the UI via **Import from env file**.

4) Enter / confirm:
   - ServiceNow instance URL (your PDI URL)
   - ServiceNow admin username/password
   - Forward base URL: `https://fwd.app/api`
   - Forward username/password
5) Click **Save**.
6) (Optional) If your PDI is sleeping, use **PDI status → Wake up**.
7) Click **Install demo app**.

## Notes

- ServiceNow calls Forward SaaS directly. Skyforge is only used to install/configure the ServiceNow artifacts.
- The installer uses ServiceNow’s Table API to create/update records and will overwrite demo artifact contents by name (tables, fields, scripts, widget, REST message).
