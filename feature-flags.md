# Feature Flags / Component Toggles (Helm)

Skyforge is designed to support **“minimal” installs** (core API + UI) and **full installs** (tools like Gitea/MinIO/Dex/Coder/NetBox/Nautobot/DNS).

All toggles are configured via Helm values in `charts/skyforge/values.yaml` and can be overridden in your deployment overlay (for example `deploy/skyforge-values.yaml`).

## Core principles

- Disabling a component should:
  - not render its Kubernetes resources (Deployments/Services/Jobs/PVCs)
  - remove its Traefik routes (so you don’t get broken links)
  - hide its navigation items in the TanStack UI (via `/api/ui/config`)
- Some components are “optional but recommended” unless you provide an external replacement (e.g. Git + S3).

## Component toggles

These values control whether Skyforge deploys and exposes the in-cluster tool:

- `skyforge.gitea.enabled` (default `true`)
- `skyforge.minio.enabled` (default `true`)
- `skyforge.dex.enabled` (default `true`)
- `skyforge.coder.enabled` (default `true`)
- `skyforge.yaade.enabled` (default `true`)
- `skyforge.swaggerUI.enabled` (default `true`)
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

## External replacements (when disabling in-cluster components)

### Git provider (when `skyforge.gitea.enabled=false`)

Skyforge still needs a Git provider for workspaces/templates. Configure:

- `skyforge.gitea.apiUrl` (required by chart validation when in-cluster Gitea is disabled)
- `skyforge.gitea.url` (optional; used for UI links/branding)
- Secrets for Git credentials (see `deploy/skyforge-secrets.yaml` in non-OSS environments)

### Object storage (when `skyforge.minio.enabled=false`)

Skyforge still needs an S3-compatible endpoint for artifacts.

- `skyforge.objectStorage.endpoint` must be set to a non-MinIO endpoint (chart validates this)
- `skyforge.objectStorage.useSsl` as needed
- Access/secret key secrets must exist (see `charts/skyforge/templates/secrets.yaml` and your deployment overlay)

### Auth (when `skyforge.dex.enabled=false`)

If you disable in-cluster Dex, you must provide an external OIDC issuer and client secrets.

- Provide `ENCORE_CFG_SKYFORGE.OIDC.*` via `skyforge.encoreCfg.json` (typed Encore config)
- Provide `OIDCClientID/OIDCClientSecret` via secrets

### Forward Networks integration (when `skyforge.forward.enabled=false`)

If you disable Forward integration, Skyforge will:

- hide the Collector UI
- disable Forward API endpoints (for example `/api/forward/*`)
- skip Forward sync actions on deployments

## Minimal install example

See `docs/examples/values-minimal.yaml` for a renderable “minimal” values overlay.

This is a shortened example that disables most optional tools while pointing to external Git + S3:

```yaml
skyforge:
  gitea:
    enabled: false
    apiUrl: "https://git.example/api/v1"
  minio:
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
  swaggerUI:
    enabled: false
  netbox:
    enabled: false
  nautobot:
    enabled: false
  dns:
    enabled: false
```

Note: disabling Dex requires external OIDC configuration; the snippet above shows only chart toggles.
