# Secrets Management

Skyforge is designed to be self-hosted and OSS-friendly. **Do not commit secrets to git.**

## Where secrets should live

Preferred (Kubernetes, OSS baseline):
- Pre-create Kubernetes Secrets in the target namespace.
- Deploy Helm with `secrets.create=false` so secret literals do not land in Helm
  release values/history.
- Keep secret material out of tracked files (`values.yaml`, docs examples, etc.).

Compatibility mode (local/dev only):
- `secrets.create=true` with a local, untracked secrets values file is still
  supported for quick bootstrap drills.
- Do not use this mode for production/OSS release baselines.

Local development:
- Use `.env` locally (it is gitignored by default via `.gitignore`).
- Use `.env.example` as the non-secret template.

## Automated secret scanning

CI runs **gitleaks** (`.github/workflows/security-ci.yml`). If secrets are committed, CI should fail.

## What counts as a secret here

Examples:
- Forward credentials
- OIDC client secrets
- LDAP bind passwords
- Object storage access/secret keys
- Any private keys/certificates (TLS/SSH CA keys, etc.)

If you accidentally committed a secret:
1. Rotate it immediately.
2. Remove it from git history (if required for public release).

## Example: pre-create a secret

```bash
kubectl -n skyforge create secret generic skyforge-admin-shared \
  --from-literal=password='<admin-password>'
```
