# Configuration quick reference

Skyforge is configured entirely via environment variables and secrets. For k3s deployments, prefer the
`k8s/overlays/k3s-traefik-secrets/` overlay and set values in `config.env`.

## 1) Core hostnames
- `SKYFORGE_HOSTNAME`: primary hostname (comma-separated aliases also supported).

## 1a) Minimum values for local k3s
At minimum, set:
- `SKYFORGE_HOSTNAME`
- `SKYFORGE_ADMIN_EMAIL`
- `SKYFORGE_CORP_EMAIL_DOMAIN`
- `SKYFORGE_GITEA_URL`, `SKYFORGE_GITEA_API_URL`
- `SKYFORGE_SEMAPHORE_URL`

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
- `SKYFORGE_CORP_EMAIL_DOMAIN`: email domain used for login hints (Azure/GCP).
- `SKYFORGE_ADMIN_EMAIL`: admin email used to seed Gitea/NetBox/Nautobot/Semaphore.
- `SKYFORGE_ADMIN_USERNAME`: admin username used for provisioning in Semaphore/Gitea.
- `SKYFORGE_ADMIN_NAME`: admin display name used for provisioning in Semaphore.
- `SKYFORGE_PROVISIONER_LOGIN`: service user name for automation provisioning.
- `SKYFORGE_PROVISIONER_NAME`: display name for the provisioner user.
- `SKYFORGE_PROVISIONER_EMAIL`: email for the provisioner user.
- `SKYFORGE_ADMIN_USERS`: comma-separated admin usernames for Skyforge access control.

## 3a) Shared admin secret (k3s overlay)
The local admin password is stored in a single secret file and reused across Skyforge,
Gitea, Semaphore, NetBox, Nautobot, and the code-server sync job:
- `k8s/overlays/k3s-traefik-secrets/secrets/skyforge_admin_shared_password`
LDAP credentials live in separate secrets and are only required if you enable LDAP.

## 4) Integration endpoints (optional)
- `SKYFORGE_GITEA_URL`: base URL for Git provider (e.g. `http://gitea:3000`).
- `SKYFORGE_GITEA_API_URL`: API base URL for Git provider (e.g. `http://gitea:3000/api/v1`). Note: Gitea’s REST API is versioned; Skyforge’s own API is unversioned under `/api/*`.
- `SKYFORGE_NETBOX_URL`: NetBox base URL.
- `SKYFORGE_NAUTOBOT_URL`: Nautobot base URL.
- `SKYFORGE_OBJECT_STORAGE_ENDPOINT`: S3-compatible endpoint (host:port).
- `SKYFORGE_OBJECT_STORAGE_USE_SSL`: `true` or `false`.

## 4a) Lab server pools (optional)
- `SKYFORGE_EVE_SERVERS_JSON`: JSON array (or `{"servers":[...]}`) describing EVE-NG servers.
- `SKYFORGE_EVE_SERVERS_FILE`: file path containing the same JSON.
- `SKYFORGE_EVE_API_URL`: fallback single EVE API URL (used if no servers JSON is provided).
- `SKYFORGE_LABPP_API_URL`: optional LabPP API base URL (defaults to `<eve web>/labpp` when unset).
- `SKYFORGE_LABPP_SKIP_TLS_VERIFY`: `true` or `false` for LabPP API TLS verification.
- `SKYFORGE_NETLAB_SERVERS_JSON`: JSON array (or `{"servers":[...]}`) describing Netlab servers.
- `SKYFORGE_NETLAB_SERVERS_FILE`: file path containing the same JSON.

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

## 6) Semaphore defaults (optional)
- `SKYFORGE_SEMAPHORE_URL`: API base URL (e.g. `http://semaphore:3000/semaphore/api`).
- `SKYFORGE_SEMAPHORE_PROJECT_ID`: default project ID for provisioning.
- `SKYFORGE_SEMAPHORE_USERNAME`: service user for provisioning.
- `SKYFORGE_SEMAPHORE_ADMIN_USERNAME`: admin username for provisioning.
- `SKYFORGE_SESSION_COOKIE`: cookie name for Skyforge sessions.

## 7) Git defaults (optional)
- `GITEA_ADMIN_USERNAME`: admin username for initial Gitea bootstrap.
- `GITEA_ALLOWED_DOMAINS`: comma-separated domains allowed for repo migration (optional).

## 8) Runtime tuning (optional)
- `SKYFORGE_LISTEN_ADDR`: HTTP listen address (default `:8085`).
- `SKYFORGE_MAX_GROUPS`: maximum LDAP groups to load.
- `SKYFORGE_PROJECT_SYNC_SECONDS`: project sync interval.
- `SKYFORGE_SESSION_TTL`: session lifetime (e.g. `8h`).
- `SKYFORGE_COOKIE_SECURE`: `true` or `false`.
- `SKYFORGE_COOKIE_DOMAIN`: optional cookie domain attribute (set when you need SSO across subdomains).
- `SKYFORGE_STATE_BACKEND`: `postgres` or `file`.
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
