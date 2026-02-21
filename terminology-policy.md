# Skyforge Terminology Policy (Hard-Cut)

This repository is user-scoped by default. Internal Skyforge architecture must use user-scope terminology only.

## Required Internal Terms

- `user`
- `scope`
- `deployment`
- `run`
- `template`

## Forbidden Legacy Architecture Terms

- `workspace`
- `project` (unless provider-native)
- `account` (unless provider-native)

## Allowed Exceptions

- Provider-native terms:
  - AWS account/accountId
  - GCP service account/project
  - Cloudflare account
  - Forward account (vendor account wording)
- Kubernetes-native terms:
  - `ServiceAccount`
  - `serviceAccountName`
- Historical references in archived evidence files under `components/docs/` are tolerated only when explicitly marked as historical.

## Enforcement

- CI/local checks run `scripts/check-portal-terminology.sh`.
- New code should not introduce account/project/workspace naming for Skyforge-owned scope concepts.
