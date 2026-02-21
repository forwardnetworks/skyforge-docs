# Feature Flags & Optional Components

Skyforge UI reads `/api/ui/config` and hides navigation items based on the `features` object.

## Helm values -> UI features

These are set by the Helm chart in `components/charts/skyforge/templates/encore-cfg-secret.yaml` via `ENCORE_CFG_SKYFORGE.Features`.

| Helm value | UI config key | Effect |
|---|---|---|
| `skyforge.gitea.enabled` | `features.giteaEnabled` | Enables Git (Gitea) integrations and template listing from Gitea. |
| `skyforge.s3gw.enabled` | `features.objectStorageEnabled` | Enables in-cluster S3-compatible object storage pathing. |
| `skyforge.dex.enabled` | `features.dexEnabled` | Enables OIDC login (Dex). |
| `skyforge.coder.enabled` | `features.coderEnabled` | Enables Coder SSO links. |
| `skyforge.yaade.enabled` | `features.yaadeEnabled` | Enables API testing (Yaade) SSO link. |
| `skyforge.redoc.enabled` | `features.apiDocsEnabled` | Enables ReDoc link. |
| `skyforge.forward.enabled` | `features.forwardEnabled` | Enables Forward collector + sync UI. |
| `skyforge.netbox.enabled` | `features.netboxEnabled` | Enables NetBox link/SSO plumbing (when deployed). |
| `skyforge.nautobot.enabled` | `features.nautobotEnabled` | Enables Nautobot link/SSO plumbing (when deployed). |
| `skyforge.dns.enabled` | `features.dnsEnabled` | Enables DNS (Technitium) SSO link (when deployed). |

## Recommended minimal install
- Disable `forward`, `netbox`, `nautobot`, `dns`, `coder`, `yaade` unless you explicitly deploy/configure them.
- Keep `gitea` if you want template browsing; otherwise switch to external Git.

## Debugging
- Check current UI feature flags: `GET /api/ui/config`
- If a link shows but returns `{"code":"not_found"}`:
  - disable the feature flag, or
  - fix routing/backend for that subsystem.
