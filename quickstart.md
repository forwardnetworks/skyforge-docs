# Quickstart (QA/PROD Environments)

This is the supported environment-scoped deployment path.

## 1) Prereqs
- access to the target QA or PROD Kubernetes host/context
- Cilium installed as the cluster CNI with Gateway API enabled
- a DNS name for Skyforge
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
- `skyforge.auth.mode=oidc` for QA/PROD

Minimum secrets to populate:
- `secrets.items.skyforge-session-secret.skyforge-session-secret`
- `secrets.items.skyforge-admin-shared.password`
- DB passwords
- object-storage keys
- `proxy-tls` (`tls.crt`, `tls.key`)

## 3) Install
Preferred environment-scoped flow:

```bash
./scripts/set-skyforge-context.sh qa
./scripts/deploy-skyforge-env.sh qa
```

## 4) Verify

```bash
./scripts/post-upgrade-gates.sh
```

## 5) Template catalog
See `components/docs/install-on-server.md` for blueprint seeding and repeatable install drills.
