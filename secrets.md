# Secrets Management

Skyforge is designed to be self-hosted and OSS-friendly. **Do not commit secrets to git.**

## Where secrets should live

Preferred (Kubernetes):
- Use Kubernetes Secrets referenced by the Helm chart (`charts/skyforge/values.yaml`).
- Keep secret material out of `values.yaml`; use Secret refs (name/key) instead.

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

