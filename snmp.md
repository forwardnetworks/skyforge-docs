# SNMP Traps (Telegraf collector)

Skyforge can optionally ingest SNMP traps directly on the k3s nodes (UDP/162)
and store them in Postgres.

Skyforge routes traps to users by **SNMPv2c community string** (per-user).

## Enable trap ingest

The Helm chart deploys a **Telegraf DaemonSet** (multi-node ready) that listens
on UDP/162 and forwards traps to the Skyforge server’s internal ingest API.

Set these values:

- `skyforge.snmpTraps.enabled: true`

Then upgrade the release.

## Get your community string

In the authenticated UI, open `Dashboard → SNMP` and copy your community
string.

Configure devices to send traps to:

- host: the Skyforge hostname
- port: `162/udp`
- community: your per-user community string

## Ports and networking

- Traps are received on **UDP/162** on each node (`hostPort` / `hostNetwork`).
- Traefik is not involved.
- Ensure firewalls/security groups allow inbound UDP/162 from your lab sources.

