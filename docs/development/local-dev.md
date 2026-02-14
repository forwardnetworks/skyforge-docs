# Local Development

From repository root:

```bash
make bootstrap
make test
```

Component-level checks:

- server: `cd components/server && encore test ./...`
- portal: `cd components/portal && pnpm lint && pnpm type-check`
- chart: `helm lint components/charts/skyforge`
