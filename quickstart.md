# Quickstart (single-node k3s)

This is the supported OSS and local deployment path.

## 1) Prereqs
- single-node `k3s` installed and `kubectl` works
- Cilium installed as the cluster CNI with Gateway API enabled
- a DNS name for Skyforge, or a local `/etc/hosts` entry
- TLS cert + key available for `proxy-tls`

## 2) Prepare values and secrets
Populate:
- `deploy/skyforge-values.yaml`
- `deploy/skyforge-secrets.yaml`

Minimum values to update:
- `skyforge.hostname`
- `skyforge.domain`
- `skyforge.gateway.addresses`
- `skyforge.gitea.url`
- `skyforge.gitea.apiUrl`
- `skyforge.auth.mode=local` for OSS/local, or `skyforge.auth.mode=oidc` for production

Minimum secrets to populate:
- `secrets.items.skyforge-session-secret.skyforge-session-secret`
- `secrets.items.skyforge-admin-shared.password`
- DB passwords
- object-storage keys
- `proxy-tls` (`tls.crt`, `tls.key`)

## 3) Install
Preferred host-first flow:

```bash
export SKYFORGE_SECRETS_VALUES=./deploy/skyforge-secrets.yaml
sudo -E ./scripts/install-on-host.sh
```

Repo-local helper for an existing single-node k3s cluster:

```bash
./scripts/deploy-skyforge-local.sh
```

## 4) Verify

```bash
./scripts/verify-local-stack.sh
```

## 5) Template catalog
See `components/docs/install-on-server.md` for blueprint seeding and repeatable install drills.
