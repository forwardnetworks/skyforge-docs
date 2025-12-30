# Syslog (Vector collector)

Skyforge can optionally ingest syslog directly on the k3s nodes (UDP/514) and
store it in Postgres.

Because plain syslog has no authentication, Skyforge routes events to users by
**source IP / CIDR mapping** (admin-managed). Users then filter to “My syslog”
in the UI.

## Enable syslog ingest

The Helm chart deploys a **Vector DaemonSet** (multi-node ready) that listens
on UDP/514 and forwards events to the Skyforge server’s internal ingest API.

Set these values:

- `skyforge.syslog.enabled: true`

Then upgrade the release.

## Manage routes (admin)

Routes map sender CIDRs to an owner username:

- CIDR: e.g. `10.128.18.0/24` or `10.128.18.5/32`
- Owner: LDAP username (e.g. `craigjohnson`)

The admin UI can list and update routes.

## Ports and networking

- Syslog is received on **UDP/514** on each node (`hostPort` / `hostNetwork`).
- Traefik is not involved.
- Ensure firewalls/security groups allow inbound UDP/514 from your lab sources.
