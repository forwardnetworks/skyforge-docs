# Quickstart (k3s + Cilium Gateway API)

This is the minimal single-node k3s deployment path.

For local development using k3d (default-safe workflow), use:
- `components/docs/k3d-local-dev.md`

If you want a repeatable install workflow, use `docs/install-on-server.md`.

## 1) Prereqs
- k3s installed and `kubectl` works.
- Cilium installed as the cluster CNI (Gateway API enabled).
- A DNS name for Skyforge (or `/etc/hosts` entry).
- TLS cert + key available for `proxy-tls`.

## 2) Configure values + secrets
Edit deployment values and local-only secrets:

```bash
$EDITOR deploy/skyforge-values.yaml
$EDITOR deploy/skyforge-secrets.yaml
```

Minimum values to update:
- `skyforge.hostname`
- `skyforge.domain`
- `skyforge.gateway.addresses` (recommended for node-IP ingress, example `type: IPAddress`, `value: 10.128.16.60`)
- `skyforge.gitea.url`
- `skyforge.gitea.apiUrl`
- `skyforge.auth.mode=password` for local/dev/OSS, or `skyforge.auth.mode=oidc` for prod
- If using prod OIDC with Okta: `skyforge.dex.enabled=true`, `skyforge.dex.authMode=oidc`, and `skyforge.dex.oidc.*`

Minimum secrets to populate:
- `secrets.items.skyforge-session-secret.skyforge-session-secret`
- `secrets.items.skyforge-admin-shared.password`
- DB passwords
- object storage keys (`object-storage-root-user`, `object-storage-root-password`)
- `proxy-tls` (`tls.crt`, `tls.key`)

## 3) Deploy (Helm)

```bash
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  -f deploy/skyforge-values.yaml \
  -f deploy/skyforge-secrets.yaml
```

## 4) Smoke tests
Follow `docs/smoke-tests.md`.

## 5) User data sync
See `docs/user-data-sync.md` for per-user paths and user-scoped object-storage artifact flow.
