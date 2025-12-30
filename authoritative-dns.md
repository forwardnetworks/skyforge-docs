# Authoritative DNS for labs (Technitium DNS)

Skyforge’s Traefik edge is HTTP(S)-only; authoritative DNS (UDP/TCP 53) is best exposed as a Kubernetes `NodePort` on the single-node k3s host.

This repo includes an optional Technitium DNS deployment (authoritative + UI) that you can enable when you need lab zones and controlled AXFR for your lab domains.

## Deploy (Helm, recommended)
Enable DNS in your Helm values:

```yaml
skyforge:
  dns:
    enabled: true
    nodePort: 30053
    webNodePort: 30380
```

Then `helm upgrade --install` your Skyforge release as usual.

## Deploy (kustomize, legacy)
```bash
kubectl apply -k k8s/infra/technitium-dns
```

## Access
- Web UI (through Skyforge DNS SSO bridge):
  - Use the DNS link inside Skyforge (it routes through `/api/dns/sso` to set a Technitium token in `localStorage`).
  - Direct `/dns/` access works too, but you must already have a valid Technitium token in your browser.
- DNS service (NodePort on the k3s node):
  - UDP/53 on node port `30053`
  - TCP/53 on node port `30053`

Example queries from another host:
```bash
dig @<hostname> -p 30053 example.lab. SOA
dig @<hostname> -p 30053 example.lab. AXFR
```

## Safe-by-default recommendations
- Keep DNS exposure scoped (firewall rules / internal VLAN).
- Configure zone transfers with an allowlist (and ideally TSIG if/when needed).
- Prefer TCP for AXFR, and limit who can perform transfers.

## Zone-transfer hardening (AXFR)

Technitium supports per-zone configuration of zone transfers; for internal use the key goals are:

- **Default deny** transfers, then allow only the specific secondaries (or tooling hosts) that require AXFR/IXFR.
- Restrict NodePort `30053` exposure at the network edge (firewall/VLAN allowlist), even if you also restrict transfers at the DNS layer.
- Prefer TSIG where possible for automation and additional protection against accidental broad transfer access.

Suggested checklist:

- Create the zone (authoritative) and verify SOA/NS over TCP.
- Enable zone transfers only to an allowlist of IPs/subnets (secondaries).
- If TSIG is available in your Technitium version, create a TSIG key and require it for transfers.
- Validate transfers from allowed and disallowed clients:
  - `dig @<hostname> -p 30053 example.lab. AXFR +tcp`
  - from a blocked host, ensure it fails/REFUSED.

## Notes
- This deployment persists config under the PVC `skyforge/technitium-dns-data`.
- Default NodePorts (`30053`, `30380`) can be changed via Helm values (recommended) or by editing `k8s/infra/technitium-dns/service.yaml` (legacy).

## DNS SSO (per-user zone)
Skyforge can optionally provision Technitium per-user access without storing your LDAP password:

- On first visit to DNS via Skyforge, you’ll be prompted for a Technitium password (you can choose to match LDAP).
- Skyforge uses that password once to create/update a Technitium user, create a per-user zone, and mint a long-lived API token.
- The token is stored encrypted in the Skyforge database and injected into the browser via the `/api/dns/sso` bridge.

By default the per-user zone is:
- `<username>.skyforge`

You can customize the suffix via:
- `SKYFORGE_DNS_USER_ZONE_SUFFIX` (defaults to `skyforge`)
