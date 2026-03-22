# Troubleshooting

## API base path confusion
Skyforge’s external API is served behind Cilium Gateway API routes under:
- `https://<hostname>/api/*`

If you try `https://<hostname>/auth/login` it will 404; the correct path is:
- `https://<hostname>/api/login`

## Swagger “Try it out” hits localhost or wrong base URL
The deployed OpenAPI schema must include a `servers` entry with:
- `url: /api`

Check:
```bash
curl -sk https://<hostname>/openapi.json | head
```

## OIDC / SSO issues
Symptoms:
- OIDC login intermittently fails.
- Browser login loops or returns to `/login`.

Notes:
- Verify Dex is reachable and configured with valid upstream OIDC settings.
- If TLS is custom, ensure trust bundles are mounted consistently across Skyforge and Dex.

## `no healthy upstream` after node reboot
Symptom:
- Gateway/Envoy returns `no healthy upstream` for Skyforge routes after host/node reboot.

Typical cause:
- Node-local Cilium datapath regression on one worker causes intermittent service DNS/TCP failures.
- `skyforge-server` then CrashLoops on startup dependency lookups (`nsq`, `db`), leaving no ready service endpoints.

Checks:
```bash
kubectl -n skyforge get pods -o wide | rg 'skyforge-server|skyforge-server-worker'
kubectl -n skyforge get endpoints skyforge-server -o wide
kubectl -n skyforge logs deploy/skyforge-server --tail=120
```

Fast remediation:
```bash
./scripts/k8s-network-resilience.sh --namespace skyforge
kubectl -n skyforge rollout restart deploy/skyforge-server deploy/skyforge-server-worker
kubectl -n skyforge rollout status deploy/skyforge-server --timeout=5m
```

Deployment guardrail:
- `scripts/deploy-skyforge-local.sh` and `scripts/deploy-skyforge-prod-safe.sh` run this resilience gate automatically (`pre-helm` + `post-helm`) in strict mode.
- `scripts/deploy-skyforge-prod-safe.sh` also enforces node kernel sysctl `fs.inotify.max_user_instances=64000` pre-Helm.
- `scripts/deploy-skyforge-prod-safe.sh` now enforces Forward worker host prerequisites pre-Helm using `scripts/k8s-forward-worker-prereqs.sh`:
  - ensures `/etc/rancher/k3s/registries.yaml` is present on nodes with Forward worker labels
  - ensures `/dev/sdg` exists (default alias target `/dev/sdb`) for Forward node-agent compatibility on newly joined workers
- Node-local Cilium datapath restarts are opt-in (`SKYFORGE_NETWORK_RESILIENCE_REPAIR=true` or explicit `--repair` workflows).

Forward worker prereq gate knobs:
- `SKYFORGE_FORWARD_WORKER_PREREQS_ENABLE` (default `true`)
- `SKYFORGE_FORWARD_WORKER_PREREQS_STRICT` (default `true`)
- `SKYFORGE_FORWARD_WORKER_PREREQS_NAMESPACE` (default `kube-system`)
- `SKYFORGE_FORWARD_WORKER_PREREQS_IMAGE` (default `busybox:1.36`)
- `SKYFORGE_FORWARD_WORKER_REGISTRY_HOST` (default `harbor.local.forwardnetworks.com`)
- `SKYFORGE_FORWARD_WORKER_REGISTRY_ENDPOINT` (default `https://harbor.local.forwardnetworks.com`)
- `SKYFORGE_FORWARD_WORKER_REGISTRY_INSECURE_SKIP_VERIFY` (default `true`)
- `SKYFORGE_FORWARD_WORKER_ENSURE_SDG_ALIAS` (default `true`)
- `SKYFORGE_FORWARD_WORKER_SDG_TARGET` (default `/dev/sdb`)
- `SKYFORGE_FORWARD_WORKER_PREREQS_NODE_TIMEOUT_SECONDS` (default `120`)

## Forward appserver 503 / collector auth drift
Symptom:
- `https://skyforge-fwd...` returns `503`.
- Forward workloads restart-loop after deploy/reboot.
- Skyforge auto collectors fail to connect even though user/org exists.

Typical cause:
- Forward DB credential secret drift (wrong usernames/passwords in `postgres.fwd-pg-*.credentials`) causes appserver/worker DB auth failures.

Checks:
```bash
kubectl -n forward get secret postgres.fwd-pg-app.credentials -o jsonpath='{.data.username}' | base64 -d; echo
kubectl -n forward get secret postgres.fwd-pg-fdb.credentials -o jsonpath='{.data.username}' | base64 -d; echo
kubectl -n forward logs deploy/fwd-appserver --tail=200 | rg -n 'password authentication failed|FATAL'
```

Expected secret usernames:
- `postgres.fwd-pg-app.credentials` -> `fwd_app`
- `postgres.fwd-pg-fdb*.credentials` -> `fwd_fdb`

Remediation:
```bash
SKYFORGE_NAMESPACE=skyforge SKYFORGE_FORWARD_NAMESPACE=forward \
  ./scripts/deploy/local/integration-repair.sh post-helm
```

Deployment guardrail:
- `scripts/deploy-skyforge-prod-safe.sh` now hard-fails if Forward secret usernames drift from the `fwd_app`/`fwd_fdb` contract and validates DB role logins before finishing deploy.

## Hoppscotch failures
### Helm upgrade failures due to immutable Jobs
If a Helm upgrade fails trying to patch a `Job`, it’s usually because the `spec.template` is immutable.

This chart runs Jobs as Helm hooks to avoid that (they are deleted/recreated automatically).

### Yaade SSO rejects login with "Password does not match"
Cause:
- The upstream Yaade image only honors `YAADE_ADMIN_USERNAME` at bootstrap.
- Its initial admin password remains the image default `password` until changed through the Yaade API.

Skyforge now runs a `yaade-admin-sync` reconciler that logs in with the image default and rotates the password to the configured `yaade-admin-password` secret.

Checks:
```bash
kubectl -n skyforge logs deploy/yaade-admin-sync --tail=100
kubectl -n skyforge get deploy yaade yaade-admin-sync
```

### Yaade data missing
Cause: the `yaade-data` PVC is missing or was reset.

Fix:
- Ensure the `yaade-data` PVC exists and is bound.
- Restart the `yaade` deployment after restoring data.

## Gitea `/api/v1` is expected
Skyforge uses Gitea’s versioned REST API under:
- `http://gitea:3000/api/v1`

Do not attempt to “remove v1” from Gitea URLs.

## Encore docker build hangs locally
Symptom:
- `encore build docker --push` appears to stall indefinitely with no progress.

Cause:
- Running `encore build docker` directly from `components/server` (a submodule with a `.git` indirection file) can trigger an Encore workspace-root resolution loop.

Required fix path:
- Do not run raw `encore build docker` for Skyforge server images.
- Use the canonical script only:

```bash
./scripts/build-push-skyforge-server.sh --tag <tag>
```

Notes:
- The script enforces standalone mirror builds and dedicated daemon isolation.
- This is the supported local build path for deterministic results.

## Encore Go toolchain drift
Symptom:
- `encore test` or `make test` fails after bumping `components/server/go.mod` to Go 1.26.

Cause:
- Encore CLI may ship an older embedded `encore-go` runtime than repo requirements.
- `encore test` uses the local Encore runtime (`~/.encore/encore-go` unless overridden), so version drift can break tests.

Fix:
- Install the patched 1.26 runtime and keep toolchain pins aligned:
  - `make install-encore-go-runtime`
  - `GOTOOLCHAIN=go1.26.1`

Pinned surfaces:
- `Makefile`
- `.github/workflows/ci.yml`
- `scripts/go-toolchain-env.sh`
- `components/server/go.mod`

Quick checks:
```bash
encore version
~/.encore/encore-go/bin/go version
echo "${GOTOOLCHAIN:-unset}"
```

## Prevent stale UI/image deploy drift
Symptom:
- A deploy "succeeds" but the UI still reflects older routes/pages.

Critical chart-source rule:
- Production deploys must use the canonical local chart source `components/charts/skyforge` synced to the remote temp path (`/tmp/skyforge-chart-sync/components/charts/skyforge`) by `scripts/deploy-skyforge-prod-safe.sh`.
- Do not run ad-hoc Helm upgrades from legacy remote chart trees (for example `/home/arch/skyforge-deploy/skyforge`).

Guardrails:
- `scripts/deploy-skyforge-prod-safe.sh` now requires explicit image refs by default:
  - `SKYFORGE_SERVER_IMAGE=<repo>:<tag>`
  - `SKYFORGE_SERVER_WORKER_IMAGE=<repo>:<tag>-worker`
- The deploy script now hard-fails when:
  - remote synced chart hash does not match local `components/charts/skyforge`,
  - the remote chart is missing `Chart.yaml` or selected values file,
  - a legacy chart directory exists on remote with a different hash (default strict mode).
- The server build now writes a build stamp:
  - `artifacts/build-stamps/server-<tag>.json`
  - `artifacts/build-stamps/latest-server-build.json`
- The deploy script hard-fails if:
  - worker tag is not `<server-tag>-worker`,
  - the build stamp for `<tag>` is missing,
  - requested image refs do not match the build stamp refs,
  - current config inputs differ from the stamp hash (for example `config.cue` changed after the image was built),
  - embedded `Netlab.Image` in `components/server/skyforge/config.cue` or `components/server/worker/config.cue` differs from the stamp,
  - the deployed image refs do not match requested refs,
  - the live `/assets/skyforge/*` entrypoint hash does not match local built `components/server/frontend/frontend_dist`.
- `scripts/deploy-skyforge-prod-safe.sh` does not use `helm --wait` by default. It validates
  readiness with explicit rollout checks for core services (`skyforge-server`,
  `skyforge-server-worker`) plus post-deploy smoke checks, so optional integrations
  (for example a halted Infoblox VM) do not block platform rollouts.
  - Set `HELM_WAIT_FOR_ALL_RESOURCES=true` if you intentionally want strict
    full-release Helm wait behavior.
- Forward DB credential reconciliation now ships `scripts/lib/forward-db-auth.sh`
  from the local repo to a remote temp path at deploy time; remote `/opt/skyforge`
  copies are no longer required for this step.

Recommended production flow:
```bash
./scripts/build-push-skyforge-server.sh --tag <tag>

SKYFORGE_SERVER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:<tag> \
SKYFORGE_SERVER_WORKER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:<tag>-worker \
SKYFORGE_ALLOW_PROD_DEPLOY=true \
./scripts/deploy-skyforge-prod-safe.sh
```

The deploy script now runs `scripts/post-deploy-smoke.sh` by default.
Disable only when needed:
```bash
RUN_POST_DEPLOY_SMOKE=false ./scripts/deploy-skyforge-prod-safe.sh
```
Bounded smoke timeout (default `240s`):
```bash
SMOKE_SERVER_TIMEOUT_SECONDS=240 ./scripts/deploy-skyforge-prod-safe.sh
```

Smoke history (admin only) is queryable at:
- `GET /api/admin/smoke-runs`
