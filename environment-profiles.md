# Skyforge Environment Profiles

Skyforge keeps deploy-side values under `deploy/` and chart-packaged mirrors
under `components/charts/skyforge/`. Keep each pair synchronized before a
rollout:

```bash
./scripts/sync-env-values.sh
```

## Hard Context Gate (Required)

To prevent QA/PROD cross-targeting, set an explicit active context before any
deploy or environment automation:

```bash
./scripts/set-skyforge-context.sh qa
# or
./scripts/set-skyforge-context.sh prod
```

Check current state:

```bash
./scripts/show-skyforge-context.sh
```

Deploy scripts now fail closed when:

- Active context and target env disagree
- URL profile is mixed (`.local` vs `.dc`)
- Remote host does not match the selected environment profile

Break-glass override (single command):

```bash
SKYFORGE_ALLOW_CONTEXT_MISMATCH=true ...
```

Production installs that cannot route directly to
`harbor.local.forwardnetworks.com` need the temporary Harbor pull bridge
documented in [prod-harbor-tunnel.md](prod-harbor-tunnel.md) before applying
Forward workloads.

## QA

The existing local install is QA:

- Skyforge URL: `https://skyforge.local.forwardnetworks.com`
- Forward URL: `https://skyforge-fwd.local.forwardnetworks.com`
- Gateway/Gitea SSH VIP: `10.128.16.80`
- Kubernetes API VIP: `10.128.16.82`
- Deploy values: `deploy/skyforge-values-qa.yaml`
- Chart mirror: `components/charts/skyforge/values-qa-skyforge-local.yaml`
- Deploy env: `deploy/environments/qa.env`

Run, after explicitly allowing a rollout:

```bash
SKYFORGE_ALLOW_PROD_DEPLOY=true ./scripts/deploy-skyforge-env.sh qa
```

## Production

The new production install is:

- Skyforge URL: `https://skyforge.dc.forwardnetworks.com`
- Forward URL: `https://skyforge-fwd.dc.forwardnetworks.com`
- Gateway/Gitea SSH address: `10.128.65.100`
- Kubernetes API endpoint: `10.128.65.203:6443`
- Deploy values: `deploy/skyforge-values-prod-labpp-sales-prod01.yaml`
- Chart mirror: `components/charts/skyforge/values-prod-labpp-sales-prod01.yaml`
- Deploy env: `deploy/environments/prod.env`

This profile sets `SKYFORGE_API_VIP_MANIFEST_FILE=none` in its deploy env
because the new single-node host uses the shared local DNS/VIP address rather
than the QA kube-vip API manifest. Do not apply the QA kube-vip API manifest to
this host unless a separate API VIP is allocated.

Run, after explicitly allowing a rollout:

```bash
SKYFORGE_ALLOW_PROD_DEPLOY=true ./scripts/deploy-skyforge-env.sh prod
```

Generate a fresh prod secret values file instead of reusing QA secrets:

```bash
./scripts/gen-secrets.sh \
  --hostname skyforge.dc.forwardnetworks.com \
  --out ./deploy/skyforge-secrets-prod-labpp-sales-prod01.yaml
```

Do not commit generated secrets.
