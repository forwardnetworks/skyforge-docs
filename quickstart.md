# Quickstart (k3s)

This is the minimal single-node k3s deployment path.

## 1) Prereqs
- k3s installed and `kubectl` works.
- A DNS name for Skyforge (or `/etc/hosts` entry).
- TLS certs available under `certs/` (self-signed is fine for dev).

## 2) Configure
Copy the overlay config and set the hostname/branding:

```bash
cp k8s/overlays/k3s-traefik-secrets/config.env.example \
   k8s/overlays/k3s-traefik-secrets/config.env
$EDITOR k8s/overlays/k3s-traefik-secrets/config.env
```

Minimum values to update:
- `SKYFORGE_HOSTNAME`
- `SKYFORGE_ADMIN_EMAIL`
- `SKYFORGE_CORP_EMAIL_DOMAIN`
- `SKYFORGE_GITEA_URL`, `SKYFORGE_GITEA_API_URL`

If you use LDAP, provide the LDAP secrets (`k8s/overlays/k3s-traefik-secrets/secrets/skyforge_ldap_url`,
`k8s/overlays/k3s-traefik-secrets/secrets/skyforge_ldap_bind_template`, and the Gitea LDAP secrets).
If you do not use LDAP, leave those secrets empty and skip the LDAP init pods.

## 3) Secrets
Secrets are file-backed and gitignored. See
`k8s/overlays/k3s-traefik-secrets/kustomization.yaml` for the full list. At
minimum you need:
- `k8s/overlays/k3s-traefik-secrets/secrets/skyforge_session_secret`
- `k8s/overlays/k3s-traefik-secrets/secrets/skyforge_admin_shared_password`
- Postgres + object storage secrets
- TLS certs under `k8s/overlays/k3s-traefik-secrets/certs/`

The shared admin password is used to seed Skyforge, Gitea, NetBox, Nautobot,
and Coder. LDAP credentials are separate and only required if you enable LDAP.


## 4) Deploy (Helm, preferred)
```bash
gh auth refresh -h github.com -s read:packages
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin

scp ./deploy/skyforge-values.yaml ./deploy/skyforge-secrets.yaml skyforge.local.forwardnetworks.com:/tmp/

ssh skyforge.local.forwardnetworks.com "helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  --version <chart-version> \
  -f /tmp/skyforge-values.yaml \
  -f /tmp/skyforge-secrets.yaml"

ssh skyforge.local.forwardnetworks.com "rm -f /tmp/skyforge-values.yaml /tmp/skyforge-secrets.yaml"
```

## 4b) Deploy (kustomize, fallback)
```bash
kubectl create namespace skyforge
kubectl apply -f k8s/traefik/helmchartconfig-plugins.yaml
kubectl apply -k k8s/overlays/k3s-quickstart
```

## 5) Smoke tests
Follow `docs/smoke-tests.md`.

## 6) Workspace sync
See `docs/workspaces.md` for how the Coder workspace directories and S3 placeholders are organized.
