# Configuration quick reference

Skyforge uses typed Encore config (`ENCORE_CFG_SKYFORGE`, `ENCORE_CFG_WORKER`) plus runtime secrets.
For k3s deployments, configure:
- values: `deploy/skyforge-values.yaml`
- secrets: `deploy/skyforge-secrets.yaml` (local-only)

## Edition
- `skyforge.edition`
  - `enterprise` (default): Forward-enabled deployments supported
  - `oss`: Forward integrations are disabled in generated config
  - `oss` cannot be combined with `skyforge.forwardCluster.enabled=true`

## Core host settings
- `skyforge.hostname`
- `skyforge.domain`
- `skyforge.publicUrl`
- `skyforge.adminUsers`
- `skyforge.audit.retention`
  - default `180d`
  - set to `0` to disable automatic audit cleanup

## Required secrets (minimum)
Populate in `deploy/skyforge-secrets.yaml` under `secrets.items`:
- `skyforge-session-secret.skyforge-session-secret`
- `skyforge-audit-export-signing-key.skyforge-audit-export-signing-key`
  - PEM-encoded Ed25519 PKCS#8 private key used to sign audit exports
- `skyforge-admin-shared.password`
- `db-skyforge-server-password.db-skyforge-server-password`
- `object-storage-root-user.object-storage-root-user`
- `object-storage-root-password.object-storage-root-password`
- `proxy-tls.tls.crt`
- `proxy-tls.tls.key`

## Audit integrity and export verification
- Integrity endpoint: `GET /api/admin/audit/integrity`
  - verifies the append-only audit hash chain
  - uses incremental checkpoints in `sf_audit_integrity_checkpoints`
- Export signing:
  - every audit export is signed with `skyforge-audit-export-signing-key`
  - signature records are persisted in `sf_audit_export_signatures`
- Verify API:
  - `POST /api/admin/audit/export-signatures/:signatureID/verify`
  - request body: `{ "bodyBase64": "<base64-export-bytes>" }`
- Admin UI flow:
  - Settings → Maintenance → Audit
  - use `Upload & verify` on a signature row to verify an exported file

## Integration endpoints
- `skyforge.gitea.url`
- `skyforge.gitea.apiUrl`
- `skyforge.netboxUrl` (optional)
- `skyforge.nautobotUrl` (optional)
- `skyforge.objectStorage.endpoint`
- `skyforge.objectStorage.useSsl`

For Gitea, keep browser navigation and clone links on `skyforge.gitea.url`
for the public `/git` path, but keep `skyforge.gitea.apiUrl` on the in-cluster
service URL for server-side jobs and workers. Demo seed raw archive reads and
Git LFS object downloads are derived from the server-side API base, so pointing
workers at the public Gateway VIP can reintroduce timeout regressions.

Gitea SSH is exposed on the same local Gateway VIP by the `gitea-ssh`
LoadBalancer service. Use `git@skyforge.local.forwardnetworks.com:<owner>/<repo>.git`
on port `22`; there is no separate `gitea.skyforge.forwardnetworks.com` SSH
hostname in the local profile. `skyforge.gateway.ciliumLBIPAM.sharedIP` and
`skyforge.gateway.addresses` should both stay set to the reserved VIP so HTTP,
HTTPS, and Gitea SSH continue to share the same address.

## Forward ownership
- `skyforge.forwardCluster.enabled=true` enables the dedicated Forward hostname
  and shared-cluster integration contract.
- `deploy/skyforge-values.yaml` is the canonical Forward source of truth for the
  supported local production profile.
- `skyforge.forwardCluster.core.owner=skyforge` and
  `skyforge.forwardCluster.workers.owner=skyforge` move the shared-cluster
  Forward stack into the Skyforge chart as a single owner.
- `skyforge.forwardCluster.core.adoptionAcknowledged=true` and
  `skyforge.forwardCluster.workers.adoptionAcknowledged=true` are required
  guards for that ownership transfer.
- The native Skyforge Forward stack intentionally does not render a shared
  built-in `fwd-collector`; `skyforge.forwardCollector.*` only controls the
  image used for Skyforge-managed user collectors.
- Forward 26.4 snapshot upload and backup/restore paths require
  `skyforge.forwardCluster.core.cbr.enabled=true`,
  `skyforge.forwardCluster.core.cbr.s3Agent.enabled=true`, and the chart-managed
  `fwd-s3-backup-settings` sync to be enabled in the supported profiles.
- `skyforge.forwardCluster.core.cbr.agent.replicas` and
  `skyforge.forwardCluster.core.cbr.s3Agent.replicas` must stay `1` in the
  supported profile because their scratch paths use single RWO PVCs.
- The CBR S3 settings sync copies the existing Skyforge object-storage secret
  values into the Forward namespace and points Forward at in-cluster `s3gw`
  (`forward-platform-backups`) without storing secret material in values.

## Object storage
- In-cluster default: `skyforge.s3gw.enabled=true` and `skyforge.objectStorage.endpoint=s3gw:7480`.
- External S3: set `skyforge.s3gw.enabled=false` and point `skyforge.objectStorage.endpoint` to external host:port.

## Auth modes
- Skyforge browser auth is selected with `skyforge.auth.mode`.
- Dev / OSS baseline: `skyforge.auth.mode=local`
  - Browser login uses `/login/local` + `POST /api/login`
  - Shared bootstrap password source: `skyforge-admin-shared.password`
- Prod baseline: `skyforge.auth.mode=oidc`
  - Browser login uses `GET /api/auth/oidc/login`
  - Supported OIDC topology is `Skyforge -> Dex -> IdP`
  - For Okta, keep `skyforge.dex.enabled=true`, `skyforge.dex.manageConfig=true`, `skyforge.dex.authMode=oidc`, and populate `skyforge.dex.oidc.*` + `dex-oidc-client-secret`
- On install, hook job `skyforge-auth-runtime-sync` writes `sf_settings` auth keys (`ui_auth_primary_provider`, `ui_oidc_enabled`, `oidc_*`) from chart values/secrets so runtime auth mode stays aligned with declarative config.
- To also run this hook on upgrades, set `skyforge.hooks.authRuntimeSync.runOnUpgrade=true`.
- Dex connector settings (`skyforge.dex.*`) control Dex's upstream identity provider. They do not replace `skyforge.auth.mode`.

## Helm hook semantics
- Bootstrap/reconcile hooks are install-only by default to keep upgrades deterministic:
  - `skyforge.hooks.authRuntimeSync.runOnUpgrade`
  - `skyforge.hooks.dbProvision.runOnUpgrade`
  - `skyforge.hooks.gatewayNodePortsReconcile.runOnUpgrade`
  - `skyforge.hooks.coderAdminBootstrap.runOnUpgrade`
  - `skyforge.hooks.giteaActionsRunnerTokenReconcile.runOnUpgrade`
- Hook jobs expose `backoffLimit` and `activeDeadlineSeconds` under each `skyforge.hooks.*` block.

## Workload priority and reliability
- Optional priority class generation:
  - `skyforge.priorityClasses.create`
  - `skyforge.priorityClasses.core.*`
  - `skyforge.priorityClasses.integrations.*`
  - `skyforge.priorityClasses.labs.*`
- Assign classes:
  - Core: `skyforge.corePriorityClassName`, `skyforge.server.priorityClassName`, `skyforge.worker.priorityClassName`
  - Heavy integrations: `skyforge.integrationsPriorityClassName`, `skyforge.rapid7.priorityClassName`, `skyforge.elk.priorityClassName`
  - Labs: `skyforge.labPriorityClassName`
- Core API disruption budget:
  - `skyforge.server.pdb.enabled`
  - `skyforge.server.pdb.minAvailable`
- Kubernetes API Priority and Fairness (APF):
  - `skyforge.apiPriorityAndFairness.create`
  - `skyforge.apiPriorityAndFairness.priorityLevels.platform.*`
  - `skyforge.apiPriorityAndFairness.priorityLevels.labControllers.*`
  - `skyforge.apiPriorityAndFairness.flowSchemas.platform.*`
  - `skyforge.apiPriorityAndFairness.flowSchemas.labControllers.*`
  - Use this to keep `system:serviceaccounts:skyforge` responsive while pushing KNE/KubeVirt/meshnet controller traffic into a lower-priority queue.
  - APF can only classify by request metadata. If lab orchestration and platform orchestration share the same Kubernetes client identity, APF cannot fully separate them; deeper separation requires a dedicated lab service account/client path.

## Integration auth modes (sidebar)
- Sidebar and tool-catalog exposure are now fail-closed: integrations are
  hidden until their minimum launch contract is valid, instead of being shown
  as broken routes.
- Native OIDC (no Skyforge SSO proxy hop): `Gitea`, `NetBox`, `Nautobot`, `Coder`, `API Testing`.
- Native OIDC (no Skyforge SSO proxy hop): `Grafana` (via Dex static client `grafana`).
- `Gitea` onboarding defaults are controlled by `skyforge.gitea.oidc.*`; the prod baseline should keep
  auto-registration enabled and account linking set to `auto` so first-time Dex users land directly in Gitea.
- `Coder` onboarding defaults are controlled by `skyforge.coder.*`; the chart now bootstraps a first owner
  account by default, keeps Dex-backed OIDC auto-login/signups enabled, and now manages a single persistent
  personal VS Code workspace per user through `skyforge.coder.automation.*` and `skyforge.coder.personalWorkspace.*`.
  The default sidebar launch path is `/api/coder/session`, which reconciles the user/workspace and redirects into
  the user's `code-server` app instead of dropping them on the generic Coder dashboard. If the published Skyforge
  hostname uses a private certificate chain, set `skyforge.coder.personalWorkspace.publicCA.*` so workspace agents
  trust that ingress CA when downloading the Coder agent binary.
- `Jira` and `Rapid7` are exposed only when the feature is enabled and the
  routed launch base URL is configured. Leaving the feature on without a valid
  upstream contract no longer publishes a broken sidebar entry.
- `Grafana` native OIDC keeps the browser redirect on `https://<hostname>/dex/auth`, but defaults the
  server-side token and userinfo exchange to in-cluster Dex (`http://dex:5556/dex/...`) so Grafana does not fail
  OAuth completion on internal TLS or ingress trust issues.
- Managed observability dashboards are provisioned by explicit ConfigMap mounts in Grafana, not by dashboard sidecars.
  - `skyforge.observability.dashboards.enabled` turns on the built-in dashboard pack.
  - `skyforge.observability.dashboards.folder` controls the Grafana folder name.
  - `skyforge.observability.dashboards.labelKey` / `labelValue` remain accepted only as deprecated no-op compatibility settings.
- OIDC-gated at edge (Skyforge/Dex SSO proxy): `Prometheus`, `Jira`, `Rapid7`, `ELK`, `Infoblox`.
  - Gate controls (enabled by default when integration is enabled):
    - `skyforge.jira.oidc.enabled`
    - `skyforge.rapid7.oidc.enabled`
    - `skyforge.elk.oidc.enabled`
    - `skyforge.infoblox.oidc.enabled`
  - This mode requires:
    - `skyforge.dex.enabled=true`
    - `skyforge.auth.mode=oidc`
  - Managed `Jira` can now preseed its Postgres `dbconfig.xml` from
    `skyforge.jira.database.*` so first-run users land in the app instead of the
    Atlassian database setup wizard.
  - `Rapid7` TLS upstream is controlled by `skyforge.rapid7.oidc.upstream*`.
  - `Infoblox` defaults to HTTP upstream port `80` in OIDC gate mode; override with
    `skyforge.infoblox.oidc.upstream*` if HTTPS upstream is required.
- Direct route (unauthenticated docs endpoint): `ReDoc` (`/redoc` routes directly to `redoc` service).
- If converting a proxy-backed integration to native OIDC, hard-cut the proxy route and keep the portal launch URL on the tool's native OIDC start endpoint.

## Service URLs
- `GITEA_ROOT_URL`: generated from `skyforge.hostname`
- Human-readable artifacts browser: `https://<hostname>/files` (redirects to `/dashboard/s3`)
- Raw object storage route: `https://<hostname>/files/<object-key>`

## Portal build artifacts
- `components/server/frontend/frontend_dist` is the canonical embedded SPA output consumed by the server binary.
- `components/portal` builds directly into that directory:
  - `pnpm build`
  - `scripts/sync-frontend-dist.mjs`
- If portal code changes are part of a rollout, the corresponding `components/server/frontend/frontend_dist/*` updates must be included intentionally in the same rollout.

## Embedded tool launch and wake rules
- Tool visibility is controlled by the tool catalog and the user's UI experience mode (`simple` or `advanced`).
- Standby integrations (`NetBox`, `Nautobot`, `Rapid7`, `Kibana`) expose a `wakeAction` through `/api/platform/integrations/status`.
- Wake semantics are intentionally narrow:
  - users who can already open the advanced embedded tool may wake it to `1` replica
  - broader scale control still requires `manage_integrations`
- If wake is blocked, the embedded tool page must say so explicitly instead of implying auto-start.

## Where to set values
```bash
$EDITOR deploy/skyforge-values.yaml
$EDITOR deploy/skyforge-secrets.yaml
```

Apply:
```bash
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  -f deploy/skyforge-values.yaml \
  -f deploy/skyforge-secrets.yaml
```
