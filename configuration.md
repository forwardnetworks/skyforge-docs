# Configuration quick reference

Skyforge uses typed Encore config (`ENCORE_CFG_SKYFORGE`, `ENCORE_CFG_WORKER`) plus Encore-managed secrets.
For k3s deployments, prefer Helm and configure values in `deploy/skyforge-values.yaml` and secrets in
`deploy/skyforge-secrets.yaml` (local-only).

For OSS/packaging, start with `docs/feature-flags.md` to understand which components can be enabled/disabled at install time.

## Auth modes (recommended)

Skyforge supports these “auth shapes” in 2026-style deployments:

- **In-cluster Dex (recommended default)**: `skyforge.dex.enabled=true` and set LDAP (`SKYFORGE_LDAP_*`) or rely on “local admin only” if LDAP is not configured.
- **External OIDC provider**: `skyforge.dex.enabled=false` and provide `ENCORE_CFG_SKYFORGE.OIDC.*` (typed config) + OIDC client secrets.

Non-goals (today):
- “Local accounts for everyone” (username/password registry managed by Skyforge). This can be added later but isn’t the current default model.

## 1) Core hostnames
- `SKYFORGE_HOSTNAME`: primary hostname (comma-separated aliases also supported).

## 1a) Minimum values for local k3s
At minimum, set:
- `SKYFORGE_HOSTNAME`
- `SKYFORGE_ADMIN_EMAIL`
- `SKYFORGE_GITEA_URL`, `SKYFORGE_GITEA_API_URL`

If you are not using LDAP, leave `SKYFORGE_LDAP_*` values empty. Skyforge will
fall back to local admin authentication only.

## 2) UI branding + support
- `SKYFORGE_UI_PRODUCT_NAME`: product name displayed in the header.
- `SKYFORGE_UI_PRODUCT_SUBTITLE`: subtitle in header/footer.
- `SKYFORGE_UI_LOGO_URL`: logo path or full URL.
- `SKYFORGE_UI_LOGO_ALT`: logo alt text.
- `SKYFORGE_UI_HEADER_BG_URL`: header background image.
- `SKYFORGE_UI_SUPPORT_TEXT`: footer support text.
- `SKYFORGE_UI_SUPPORT_URL`: footer support link (optional).

## 3) Org defaults
- `ENCORE_CFG_SKYFORGE.CorpEmailDomain`: email domain used for login hints (Azure/GCP).
- `SKYFORGE_ADMIN_EMAIL`: admin email used to seed Gitea/NetBox/Nautobot.
- `ENCORE_CFG_SKYFORGE.AdminUsername`: admin username used for provisioning in Gitea.
- `SKYFORGE_ADMIN_NAME`: admin display name used for provisioning.
- `SKYFORGE_PROVISIONER_LOGIN`: service user name for automation provisioning.
- `SKYFORGE_PROVISIONER_NAME`: display name for the provisioner user.
- `SKYFORGE_PROVISIONER_EMAIL`: email for the provisioner user.
- `ENCORE_CFG_SKYFORGE.AdminUsers`: comma-separated admin usernames for Skyforge access control.

## 3a) Shared admin secret (k3s overlay)
The local admin password is stored in a single secret file and reused across Skyforge,
Gitea, NetBox, Nautobot, and Coder:
- `k8s/overlays/k3s-traefik-secrets/secrets/skyforge_admin_shared_password`
LDAP credentials live in separate secrets and are only required if you enable LDAP.

## 4) Integration endpoints (optional)
- `SKYFORGE_GITEA_URL`: base URL for Git provider (e.g. `http://gitea:3000`).
- `SKYFORGE_GITEA_API_URL`: API base URL for Git provider (e.g. `http://gitea:3000/api/v1`). Note: Gitea’s REST API is versioned; Skyforge’s own API is unversioned under `/api/*`.
- `SKYFORGE_NETBOX_URL`: NetBox base URL.
- `SKYFORGE_NAUTOBOT_URL`: Nautobot base URL.
- `SKYFORGE_OBJECT_STORAGE_ENDPOINT`: S3-compatible endpoint (host:port).
- `SKYFORGE_OBJECT_STORAGE_USE_SSL`: `true` or `false`.

### Forward Networks integration (optional)

Skyforge can optionally integrate with Forward Networks to:

- provision per-user in-cluster collectors
- sync deployments as devices/endpoints into Forward

To disable this in OSS installs, set `skyforge.forward.enabled=false` (Helm value).

### NetBox/Nautobot permissions (Remote-User)
- When `SKYFORGE_SSO_ENABLED=true`, Skyforge uses Traefik forwardAuth + `Remote-User` headers to SSO into NetBox/Nautobot.
- Skyforge also sets `Remote-User-Group: skyforge-users` so NetBox/Nautobot can grant non-superuser write permissions.
- Current scope: basic create for a small set of IPAM/DCIM object types, and change/delete limited to a per-user tenant.
  - NetBox: a `Tenant` is created (or reused) per username (by slug), and change/delete permissions are constrained to objects with `tenant=<user>` (or `device__tenant=<user>` for interfaces).
  - Nautobot: a `Tenant` is created (or reused) per username (by name), and change/delete permissions are constrained similarly.

## 4a) Lab server pools (optional)
- `SKYFORGE_EVE_SERVERS_JSON`: JSON array (or `{"servers":[...]}`) describing EVE-NG servers.
- `SKYFORGE_EVE_SERVERS_FILE`: file path containing the same JSON.
- `SKYFORGE_EVE_API_URL`: fallback single EVE API URL (used if no servers JSON is provided).
- `SKYFORGE_LABPP_FWD_ROOT`: path to the bundled `fwd` repo used by the LabPP CLI (default `/opt/skyforge/fwd`).
- `SKYFORGE_LABPP_CONFIG_DIR_BASE`: base directory for LabPP generated configs (default `/var/lib/skyforge/labpp-configs`).
- `SKYFORGE_LABPP_CONFIG_VERSION`: LabPP properties file version (default `1.0`).
- `SKYFORGE_LABPP_NETBOX_URL`: NetBox base URL used by LabPP.
- `SKYFORGE_LABPP_NETBOX_USERNAME`: NetBox username for LabPP allocations (secret).
- `SKYFORGE_LABPP_NETBOX_PASSWORD`: NetBox password for LabPP allocations (secret).
- `SKYFORGE_LABPP_NETBOX_MGMT_SUBNET`: management subnet CIDR used for LabPP (e.g. `10.255.0.0/24`).
- `SKYFORGE_LABPP_S3_ACCESS_KEY`, `SKYFORGE_LABPP_S3_SECRET_KEY`, `SKYFORGE_LABPP_S3_REGION`, `SKYFORGE_LABPP_S3_BUCKET`: optional S3 state config for LabPP.
- `SKYFORGE_NETLAB_SERVERS_JSON`: JSON array (or `{"servers":[...]}`) describing Netlab servers.
- `SKYFORGE_NETLAB_SERVERS_FILE`: file path containing the same JSON.
- `SKYFORGE_CONTAINERLAB_API_PATH`: API path for Containerlab (default `/containerlab`).
- `SKYFORGE_CONTAINERLAB_JWT_SECRET`: shared JWT secret for the Containerlab API server.
- `SKYFORGE_CONTAINERLAB_SKIP_TLS_VERIFY`: `true` or `false` for Containerlab API TLS verification.
- `SKYFORGE_PKI_CA_CERT`: PEM-encoded CA certificate used for issuance.
- `SKYFORGE_PKI_CA_KEY`: PEM-encoded CA private key used for issuance.
- `SKYFORGE_PKI_DEFAULT_DAYS`: default certificate TTL (days, default 365).
- `SKYFORGE_SSH_CA_KEY`: OpenSSH private key used to sign SSH user certificates.
- `SKYFORGE_SSH_DEFAULT_DAYS`: default SSH certificate TTL (days, default 30).

For per-server overrides in `SKYFORGE_NETLAB_SERVERS_JSON`, you can set:
- `containerlabApiUrl` (full URL override).
- `containerlabSkipTlsVerify` (`true`/`false`).

## 4b) DNS (Technitium, optional)
- `SKYFORGE_DNS_URL`: Technitium base URL for the server-to-server API (default `http://technitium-dns:5380`).
- `SKYFORGE_DNS_ADMIN_USERNAME`: Technitium admin username used for provisioning (default `admin`).
- `SKYFORGE_DNS_USER_ZONE_SUFFIX`: suffix for per-user zones (default `skyforge`, producing `<username>.skyforge`).

## 5) LDAP defaults (optional)
- `SKYFORGE_LDAP_URL`: LDAP URL (e.g. `ldap://ldap:389` or `ldaps://ldap:636`).
- `SKYFORGE_LDAP_BIND_TEMPLATE`: bind template (e.g. `uid=%s,ou=People,dc=example,dc=com`).
- `SKYFORGE_LDAP_BASEDN`: base DN for user lookup (optional).
- `SKYFORGE_LDAP_DISPLAY_ATTR`: display attribute (e.g. `cn`).
- `SKYFORGE_LDAP_GROUP_ATTR`: group attribute (e.g. `memberOf`).
- `SKYFORGE_LDAP_MAIL_ATTR`: mail attribute (e.g. `mail`).
- `SKYFORGE_LDAP_SKIP_TLS_VERIFY`: `true` or `false`.
- `SKYFORGE_LDAP_STARTTLS`: `true` or `false`.

## 6) Session defaults (optional)
- `SKYFORGE_SESSION_COOKIE`: cookie name for Skyforge sessions.

## 7) Git defaults (optional)
- `GITEA_ADMIN_USERNAME`: admin username for initial Gitea bootstrap.
- `GITEA_ALLOWED_DOMAINS`: comma-separated domains allowed for repo migration (optional).

## 8) Runtime tuning (optional)
- `SKYFORGE_LISTEN_ADDR`: HTTP listen address (default `:8085`).
- `SKYFORGE_MAX_GROUPS`: maximum LDAP groups to load.
- `SKYFORGE_WORKSPACE_SYNC_SECONDS`: workspace sync interval (preferred).
- `SKYFORGE_SESSION_TTL`: session lifetime (e.g. `8h`).
- `SKYFORGE_COOKIE_SECURE`: `true` or `false`.
- `SKYFORGE_COOKIE_DOMAIN`: optional cookie domain attribute (set when you need SSO across subdomains).
- Skyforge state is stored in Postgres (required).
- `SKYFORGE_DB_HOST`, `SKYFORGE_DB_PORT`, `SKYFORGE_DB_NAME`, `SKYFORGE_DB_USER`, `SKYFORGE_DB_SSLMODE`.
- `SKYFORGE_REDIS_ENABLED`, `SKYFORGE_REDIS_ADDR`, `SKYFORGE_REDIS_DB`, `SKYFORGE_REDIS_KEY_PREFIX`.
- `SKYFORGE_HEALTH_HTTP_CHECKS`: semicolon-separated checks (`Name|Icon|URL|Hint`).
- `SKYFORGE_HEALTH_CODE_CHECKS`: semicolon-separated checks (`Name|Icon|Token|Hint`).

## 9) Service base URLs
- `GITEA_ROOT_URL`: base URL for Git UI.
- `MINIO_BROWSER_REDIRECT_URL`: redirect target for the object storage console.
- `HOPPSCOTCH_BASE_URL`: public Hoppscotch base URL (same hostname in this environment).
- `HOPPSCOTCH_SHORTCODE_BASE_URL`: shortcode base URL (usually same as base).
- `HOPPSCOTCH_ADMIN_URL`: admin URL (usually same as base).
- `HOPPSCOTCH_BACKEND_GQL_URL`: GraphQL endpoint URL.
- `HOPPSCOTCH_BACKEND_WS_URL`: GraphQL websocket endpoint.
- `HOPPSCOTCH_BACKEND_API_URL`: REST API endpoint.
- `HOPPSCOTCH_WHITELISTED_ORIGINS`: comma-separated origins allowed by Hoppscotch.

## 10) Where to set them
For k3s (recommended):
```bash
cp k8s/overlays/k3s-traefik-secrets/config.env.example k8s/overlays/k3s-traefik-secrets/config.env
$EDITOR k8s/overlays/k3s-traefik-secrets/config.env
```

If you deploy the raw kompose manifests, update `k8s/kompose/skyforge-config-configmap.yaml` directly
(placeholders like `__SKYFORGE_HOSTNAME__` are intended to be replaced).

## 11) Build/publish registry (build-time)
- `SKYFORGE_REGISTRY`: container registry hostname used when building/pushing images
  (for example `ghcr.io/forwardnetworks` for private GHCR). This is a build-time value, not
  required by the running services.
