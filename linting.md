# Linting & CI

Skyforge uses CI checks to keep the Encore (Go) backend and TanStack (Vite/React/TS) UI consistent and safe to change.

## Server (Encore / Go)

From `server`:

```bash
go test ./...
golangci-lint run ./...
```

Optional (security):

```bash
govulncheck ./...
```

## Portal (TanStack / Vite / TS)

From `portal-tanstack`:

```bash
pnpm install
pnpm run lint
pnpm run type-check
pnpm run test
```

## GitHub Actions

Workflows live in `.github/workflows/` and are intended to be required PR checks.

Additional repo-wide checks:

- **meta-ci**: `actionlint`, `yamllint`, `shellcheck` + `shfmt`, `hadolint`, `helm lint`, `kubeconform`
- **security-ci**: `gitleaks` (blocking) + `govulncheck`/`trivy`/`pnpm audit` (informational)

## One-shot local check

From repo root:

```bash
./scripts/lint-all.sh
```
