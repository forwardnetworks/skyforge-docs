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
- `skyforge.netbox.enabled` (default `false`)
- `skyforge.nautobot.enabled` (default `false`)
- `skyforge.dns.enabled` (default `false`)

Related toggles:
- `skyforge.cloudflareTunnel.enabled` (default `false`)
- `skyforge.syslog.enabled` (default `false`)
- `skyforge.snmpTraps.enabled` (default `false`)
- `skyforge.nodeMetrics.enabled` (default `false`)
- `nsq.enabled` (default `true`)

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

### Auth (`skyforge.dex.enabled=false`)
Provide external OIDC config/secrets.

When `skyforge.dex.enabled=true`, the default OSS baseline is Helm-managed Dex config with local-password auth:
- `skyforge.dex.manageConfig=true`
- `skyforge.dex.authMode=local`
- password sourced from `skyforge-admin-shared.password`

Supported managed Dex auth modes:
- `local` (default)
- `google` (Google OAuth)
- `oidc` (generic OIDC; use for Okta)
- `ldap`

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
