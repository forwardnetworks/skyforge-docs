# Development Workflow (OSS-friendly)

This repository is intentionally set up so we *don’t* end up in the common “no tests / no CI / no rollback / poor secrets” bucket.

## Required checks (CI)

GitHub Actions workflows live in `skyforge-private/.github/workflows/` and should be treated as required PR checks:

- `server-ci`: `gofmt`, `go test`, `golangci-lint` (plus informational `govulncheck`)
- `portal-ci`: `pnpm lint`, `pnpm type-check`, `pnpm test`, `pnpm build`
- `meta-ci`: actionlint/yamllint/shellcheck/shfmt/hadolint/helm lint/kubeconform
- `security-ci`: `gitleaks` (blocking) + informational vuln checks

## One-shot local verification

Run the same core checks locally before pushing:

```bash
cd skyforge-private
./scripts/lint-all.sh
```

## Rollback discipline

Deployments are Helm-based. Keep image tags immutable (date+sha recommended) so rollbacks are predictable.

See `docs/deploy-snapshot.md` for rollback procedures.

