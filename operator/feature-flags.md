# Feature Flags & Optional Components

Skyforge is designed to run with optional subsystems. The UI reads `/api/ui/config` and hides navigation items based on the `features` object.

## Helm values → UI features

These are set by the Helm chart in `charts/skyforge/templates/encore-cfg-secret.yaml` via `ENCORE_CFG_SKYFORGE.Features`.

| Helm value | UI config key | Effect |
|---|---|---|
| `skyforge.gitea.enabled` | `features.giteaEnabled` | Enables Git (Gitea) integrations and template listing from Gitea. |
| `skyforge.minio.enabled` | `features.minioEnabled` | Enables object storage console and artifact storage via S3-compatible endpoint. |
| `skyforge.dex.enabled` | `features.dexEnabled` | Enables OIDC login (Dex). |
| `skyforge.coder.enabled` | `features.coderEnabled` | Enables Coder SSO links. |
| `skyforge.yaade.enabled` | `features.yaadeEnabled` | Enables API testing (Yaade) SSO link. |
| `skyforge.apiDocs.enabled` (or deprecated `skyforge.swaggerUI.enabled`) | `features.swaggerUIEnabled` | Enables the API docs UI (ReDoc). |
| `skyforge.forward.enabled` | `features.forwardEnabled` | Enables Forward collector + sync UI. |
| `skyforge.netbox.enabled` | `features.netboxEnabled` | Enables NetBox link/SSO plumbing (when deployed). |
| `skyforge.nautobot.enabled` | `features.nautobotEnabled` | Enables Nautobot link/SSO plumbing (when deployed). |
| `skyforge.dns.enabled` | `features.dnsEnabled` | Enables DNS (Technitium) SSO link (when deployed). |

## Recommended “minimal” install

For an OSS-like minimal install, start with only the core platform and in-cluster lab providers:
- Disable `forward`, `netbox`, `nautobot`, `dns`, `coder`, `yaade` unless you explicitly deploy/configure them.
- Keep `gitea` if you want template browsing; otherwise switch to a different template source.

## Debugging

- Check current UI feature flags: `GET /api/ui/config`
- If a link shows but returns `{"code":"not_found"}`:
  - Either disable the feature flag, or fix ingress/routes for that subsystem.

