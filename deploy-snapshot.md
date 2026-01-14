# Deploy snapshot

This file captures a known-good deployment configuration so we can reproduce the environment without copying local files onto the k3s host.

## Snapshot
### 2026-01-13 (demo)
- Date: 2026-01-13
- Hostname: `skyforge.local.forwardnetworks.com`
- Helm chart (repo): `charts/skyforge`
- Helm chart version: `0.2.205`
- Helm release revision: `759`
- Images:
  - `ghcr.io/forwardnetworks/skyforge-server:20260113-1433`
  - `ghcr.io/forwardnetworks/skyforge-server-worker:20260113-1433`
  - `ghcr.io/forwardnetworks/skyforge-portal:20260113-0903`
  - `ghcr.io/forwardnetworks/skyforge-labpp-runner:20260113-0544`
  - `ghcr.io/forwardnetworks/skyforge-netbox:20260111-1222`
  - `ghcr.io/forwardnetworks/skyforge-nautobot:20260108-0135`
  - `esperotech/yaade:latest`
- Runner notes:
  - Netlab API script updated on `tsa-eve-ng-001`: `/opt/netlab/netlab-api.py` (timestamp: 2026-01-13 10:37 PST)
- Demo-critical behavior verified:
  - Netlab: per-device Forward CLI creds created (`{deployment}-{device}`), device type hints sent when known (`linux_os_ssh`, `arista_eos_ssh`), Linux SSH enabled on Alpine/python-based hosts.
  - LabPP: EVE upload/config works, CSV generation works, Forward configuration is skipped as desired.
  - Gitea: shared `skyforge/blueprints` repo is public/visible in Explore; workspace repos are private by default.

### 2026-01-12
- Date: 2026-01-12
- Hostname: `skyforge.local.forwardnetworks.com`
- Helm chart (repo): `charts/skyforge`
- Helm chart version: `0.2.195`
- Images:
  - `ghcr.io/forwardnetworks/skyforge-server:20260112-0547`
  - `ghcr.io/forwardnetworks/skyforge-portal:20260112-0524`
  - `ghcr.io/forwardnetworks/skyforge-labpp-runner:20260111-1933`
  - `ghcr.io/forwardnetworks/skyforge-netbox:20260111-1222`
  - `ghcr.io/forwardnetworks/skyforge-nautobot:20260108-0135`
  - `esperotech/yaade:latest`

### 2025-12-29
- Date: 2025-12-29
- Hostname: `skyforge.local.forwardnetworks.com`
- Helm chart (OCI): `oci://ghcr.io/forwardnetworks/charts/skyforge`
- Helm chart version: `0.2.24`
- Images:
  - `ghcr.io/forwardnetworks/skyforge-server:20251229-052527-openapi-base`
  - `ghcr.io/forwardnetworks/skyforge-portal:20251229-100117-portal-api-testing-cookie`
  - `ghcr.io/forwardnetworks/skyforge-netbox:20251229-101706-netboxldapfix`
  - `ghcr.io/forwardnetworks/skyforge-nautobot:20251229-100652-ldapfix`
  - `esperotech/yaade:latest`

## Values highlights
- DNS: Technitium DNS enabled (`/dns/`), NodePorts `30053` (DNS) and `30380` (web UI).
- LabPP runs locally inside the skyforge-server image (no external LabPP API proxy required).
- Scheduling: periodic maintenance (task reconcile, workspace sync, cloud checks, metrics refresh) uses Encore Cron jobs (no Kubernetes CronJobs in the chart).
- Secrets: `secrets.create: false` (environment-specific secrets are managed out-of-band).

## Notes
- Skyforge’s external API is served behind Traefik under `https://<hostname>/api/skyforge/*`.
  - The embedded OpenAPI schema `servers` includes `url: /api/skyforge` so Swagger “Try it out” works.
- API Testing is linked via `https://<hostname>/api-testing/` and routes to Yaade.
- Netlab: template sync happens on deployment definition create (best-effort prefetch) and sync is scoped to the selected template subtree for faster starts.
- Portal: deleting Netlab/Lab++ deployments avoids a redundant destroy run (server handles cleanup on delete).

## Deploy / upgrade
1) Ensure Helm can pull from GHCR (one-time per host):
```bash
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin
```

2) Upgrade using the repo chart + values file:
```bash
helm upgrade --install skyforge charts/skyforge \
  -n skyforge --create-namespace \
  -f deploy/skyforge-values.yaml -f deploy/skyforge-secrets.yaml \
  --wait --timeout 10m
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
