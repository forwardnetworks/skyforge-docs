# Deploy snapshot

This file captures a known-good deployment configuration so we can reproduce the environment without copying local files onto the k3s host.

## Snapshot
- Date: 2025-12-29
- Hostname: `skyforge.local.forwardnetworks.com`
- Helm chart (OCI): `oci://ghcr.io/forwardnetworks/charts/skyforge`
- Helm chart version: `0.2.24`
- Images:
  - `ghcr.io/forwardnetworks/skyforge-server:20251229-052527-openapi-base`
  - `ghcr.io/forwardnetworks/skyforge-portal:20251229-100117-portal-api-testing-cookie`
  - `ghcr.io/forwardnetworks/skyforge-netbox:20251229-101706-netboxldapfix`
  - `ghcr.io/forwardnetworks/skyforge-nautobot:20251229-100652-ldapfix`
  - `docker.io/hoppscotch/hoppscotch@sha256:0bf0d0c1a34399d8bc4a0d89126b41c717db771c5a451d69d076cb4305b9eaff` (pinned)

## Values highlights
- DNS: Technitium DNS enabled (`/dns/`), NodePorts `30053` (DNS) and `30380` (web UI).
- LabPP proxy: enabled, routes `https://<hostname>/labpp/<server>/...` to EVE hosts on port 443.
- Secrets: `secrets.create: false` (environment-specific secrets are managed out-of-band).

## Notes
- Skyforge’s external API is served behind Traefik under `https://<hostname>/api/skyforge/*`.
  - The embedded OpenAPI schema `servers` includes `url: /api/skyforge` so Swagger “Try it out” works.
- API Testing is linked via `https://<hostname>/api-testing/`.
  - This sets a short-lived cookie and routes Hoppscotch at the same hostname (Hoppscotch requires `/` due to HTML5 history routing).
  - Exit API Testing with `https://<hostname>/api-testing/exit` to return to the portal.

## Deploy / upgrade
1) Ensure Helm can pull from GHCR (one-time per host):
```bash
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin
```

2) Upgrade using the repo values file:
```bash
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  --version 0.2.24 -n skyforge --create-namespace -f deploy/skyforge-values.yaml
```

3) Check pods:
```bash
kubectl -n skyforge get pods
```

## Rollback
1) Inspect history:
```bash
helm history skyforge -n skyforge
```

2) Roll back to a prior revision:
```bash
helm rollback skyforge <REVISION> -n skyforge
```
