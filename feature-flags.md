# Feature Flags / Component Toggles (Helm)

Skyforge supports minimal and full installs through Helm values.

## Core principles
- Disabled components should not render workloads/services/routes.
- UI navigation should match enabled backend features.
- Some components are optional if external replacements are provided (for example Git).

## Component toggles
- `skyforge.gitea.enabled` (default `true`)
- `skyforge.s3gw.enabled` (default `true`)
- `skyforge.dex.enabled` (default `true`)
- `skyforge.coder.enabled` (default `true`)
- `skyforge.yaade.enabled` (default `true`)
- `skyforge.redoc.enabled` (default `true`)
- `skyforge.forward.enabled` (default `true`)
- `skyforge.forwardCluster.enabled` (default `false`)
- `skyforge.forwardCluster.observabilityUI.enabled` (default `false`)
- `skyforge.netbox.enabled` (default `false`)
- `skyforge.nautobot.enabled` (default `false`)
- `skyforge.infoblox.enabled` (default `false`)
- `skyforge.jira.enabled` (default `false`)
- `skyforge.rapid7.enabled` (default `false`)
- `skyforge.elk.enabled` (default `false`)
- `skyforge.dns.enabled` (default `false`)

Related toggles:
- `skyforge.syslog.enabled` (default `false`)
- `skyforge.snmpTraps.enabled` (default `false`)
- `skyforge.nodeMetrics.enabled` (default `false`)
- `skyforge.keda.enabled` (default `false`)
- `nsq.enabled` (default `true`)

Observability notes:
- Forward Grafana/Prometheus UI entries are gated by `skyforge.forwardCluster.observabilityUI.enabled`.
- Forward dashboard provisioning pack is gated by `skyforge.forwardCluster.observabilityUI.dashboards.enabled`.
- `skyforge.nodeMetrics.enabled` uses Telegraf ingestion into Skyforge APIs/Postgres (not Prometheus scraping).
- Syslog ingestion uses Vector when `skyforge.syslog.enabled=true`.
- `skyforge.keda.enabled` enables KEDA resources for configured blocks (`worker`, `jira`, `netbox`, `nautobot`, `rapid7`, `elkProxy`), with per-block triggers/limits still controlled by values.
- Infoblox VM lifecycle control is handled by `skyforge.infoblox.lifecycle.*` (KubeVirt), not KEDA.
- Temp-license reconciliation for Infoblox is controlled by `skyforge.infoblox.lifecycle.license.*`.

## External replacements

### Git provider (`skyforge.gitea.enabled=false`)
Set:
- `skyforge.gitea.apiUrl`
- `skyforge.gitea.url` (optional)

### Object storage (`skyforge.s3gw.enabled=false`)
Set:
- `skyforge.objectStorage.endpoint` to external S3 endpoint
- `skyforge.objectStorage.useSsl`
- object storage access key/secret secrets

### Auth
Skyforge browser auth is selected by `skyforge.auth.mode`:
- `local`: direct Skyforge local login via `/login/local` (`POST /api/login`) (dev / OSS baseline)
- `oidc`: Skyforge browser login via `/api/oidc/login` (prod baseline)

When `skyforge.auth.mode=oidc`, keep `skyforge.dex.enabled=true`. The supported browser-OIDC topology is:
- `Skyforge -> Dex -> upstream IdP`

Dex remains configurable via `skyforge.dex.*`, but that controls Dex's connector mode rather than the Skyforge browser-auth selector.

Common Dex connector modes:
- `local` (tool SSO / standalone Dex testing)
- `google` (Google OAuth)
- `oidc` (generic OIDC; use for Okta)

## Minimal install example
```yaml
skyforge:
  gitea:
    enabled: false
    apiUrl: "https://git.example/api/v1"
  s3gw:
    enabled: false
  objectStorage:
    endpoint: "s3.example.com:9000"
    useSsl: true
  dex:
    enabled: false
  coder:
    enabled: false
  yaade:
    enabled: false
  redoc:
    enabled: false
  netbox:
    enabled: false
  nautobot:
    enabled: false
  dns:
    enabled: false
```
