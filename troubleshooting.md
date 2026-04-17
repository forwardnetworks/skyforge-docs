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

## Platform conditions show `inventory-snapshot-stale`
Symptom:
- Dashboard `Platform conditions` shows:
  - `inventory-snapshot-stale`
- Capacity and placement views lag the actual cluster even though workers are healthy.

Typical cause:
- The worker seeded the platform inventory snapshot at startup, but the recurring
  refresh path did not continue running afterward.
- The warning threshold is intentionally short (`2 minutes`), so a missed loop
  becomes visible quickly.

Checks:
```bash
kubectl -n skyforge logs deploy/skyforge-server-worker --since=2h | rg -n 'platform inventory snapshot|CronRefreshClusterInventorySnapshot'
```

Expected:
- one startup line:
  - `initial platform inventory snapshot refreshed`
- and regular follow-up refresh executions after that

Repair:
- roll the `skyforge-server-worker` deployment onto a build that includes the
  worker-local platform inventory refresh loop
- after rollout, the warning should clear within a couple of minutes once the
  next refresh updates `sf_platform_inventory_state.recorded_at`

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
- `scripts/deploy-skyforge-prod-safe.sh` runs this resilience gate automatically (`pre-helm` + `post-helm`) in strict mode.
- `scripts/deploy-skyforge-prod-safe.sh` now also hard-fails if any node is not `Ready` during pre/post Helm readiness gates.
- `scripts/deploy-skyforge-prod-safe.sh` now hard-fails if fewer than two `fwd-master` nodes are `Ready` and schedulable (not tainted `skyforge.forwardnetworks.com/disabled:NoSchedule`).
- local single-node k3s installs should run `./scripts/verify-local-stack.sh` after `./scripts/deploy-skyforge-local.sh`.
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
- `scripts/deploy-skyforge-prod-safe.sh` now hard-fails if any Forward pod reports `ErrImagePull` or `ImagePullBackOff` after Forward reconciliation.

## Forward login hangs and appserver requests stall for 60s
Symptom:
- `https://skyforge-fwd.../login` hangs or times out.
- Skyforge-managed Forward actions such as token creation or network creation
  fail with `context deadline exceeded`.
- `fwd-appserver` access logs show repeated `lat_ms:60001` / `lat_ms:120002`
  lines.

Typical cause:
- `fwd-pg-app` failed over, but the standby did not reattach cleanly.
- Patroni is still in synchronous replication mode, so app commits block on
  `SyncRep`.
- `fwd-appserver` then exhausts its small JDBC pool and appears down even though
  the pod stays `Ready`.

Checks:
```bash
kubectl -n forward exec fwd-pg-app-2 -- psql -U postgres -d postgres -c \
  "show synchronous_standby_names; select application_name, state, sync_state from pg_stat_replication;"
kubectl -n forward exec fwd-pg-app-2 -- psql -U postgres -d postgres -c \
  "select pid, wait_event_type, wait_event, now()-query_start as age, left(query,120) from pg_stat_activity where state='active' order by query_start asc limit 12;"
kubectl -n forward exec fwd-appserver-<pod> -c appserver -- sh -lc \
  'curl -sk --max-time 10 -o /dev/null -w "%{http_code} %{time_total}\n" https://localhost:8443/login'
```

Expected in the healthy local/demo profile:
- `synchronous_standby_names` is empty
- `pg_stat_replication` may be empty during standby repair, but commits should
  still proceed
- `/login` returns quickly instead of hanging behind blocked DB commits

Guardrail:
- The local Forward bootstrap overlays now set:
  - `app.patroni.synchronous_mode=false`
  - `app.patroni.synchronous_mode_strict=false`
- That makes local/demo Forward prefer availability over synchronous durability
  when a standby drifts or is recovering after failover.

## Forward snapshot reprocess fails with read-only FDB errors
Symptoms:
- Snapshot reprocess fails in Forward after making visible progress.
- Appserver or backend logs show one or more of:
  - `cannot assign OIDs during recovery`
  - `cannot execute CREATE DATABASE in a read-only transaction`
  - `The connection attempt failed`
- In the worst case, `fwd-appserver` may restart-loop and the Gateway returns:
  - `upstream connect error or disconnect/reset before headers`

Typical cause:
- A Patroni failover or reconciliation window temporarily moves the writable FDB
  primary.
- During that window, the `fwd-pg-fdb-*` primary and `-repl` services can lag
  behind the current pod roles, or Forward consumers can keep stale JDBC pools
  pinned to the old side.
- Snapshot aggregation then attempts writes on a recovering replica and fails.

Checks:
```bash
kubectl -n forward get svc,endpoints \
  fwd-pg-fdb-0 fwd-pg-fdb-0-repl fwd-pg-fdb-1 fwd-pg-fdb-1-repl -o wide
kubectl -n forward exec fwd-pg-fdb-0-1 -- psql -U postgres -tAc 'select inet_server_addr(), pg_is_in_recovery();'
kubectl -n forward exec fwd-pg-fdb-0-2 -- psql -U postgres -tAc 'select inet_server_addr(), pg_is_in_recovery();'
kubectl -n forward exec fwd-pg-fdb-1-1 -- psql -U postgres -tAc 'select inet_server_addr(), pg_is_in_recovery();'
kubectl -n forward exec fwd-pg-fdb-1-2 -- psql -U postgres -tAc 'select inet_server_addr(), pg_is_in_recovery();'
```

Expected:
- `fwd-pg-fdb-0` and `fwd-pg-fdb-1` point at the pods where
  `pg_is_in_recovery() = false`
- the corresponding `-repl` services point at the replica pods

Repair:
```bash
SKYFORGE_NAMESPACE=skyforge SKYFORGE_FORWARD_NAMESPACE=forward \
  ./scripts/deploy/local/integration-repair.sh post-helm
```

What the repair now does:
- verifies Patroni primary and replica service endpoints for:
  - `fwd-pg-app`
  - `fwd-pg-fdb-0`
  - `fwd-pg-fdb-1`
- deletes stale Endpoints objects if they no longer match current pod roles
- waits for the Postgres operator to republish the correct primary/replica
  routing
- restarts `fwd-appserver`, `fwd-backend-master`, `fwd-compute-worker`, and
  `fwd-search-worker` so stale DB sessions are dropped cleanly

Relevant knobs:
- `SKYFORGE_FORWARD_REPAIR_PATRONI_SERVICE_ROUTING` (default `true`)
- `SKYFORGE_FORWARD_PATRONI_SERVICE_WAIT_SECONDS` (default `60`)

## Forward opens malformed URL (for example `https://forwardnetworks/.`)
Symptom:
- Clicking **Demo Org** (or other Forward SSO links) opens a broken URL or lands on a blank/malformed Forward host.

Typical cause:
- `fwd-appserver` is missing `-Dforward.baseurl=...` in `APPSERVER_SETTINGS`.
- This can happen after a direct Forward Helm upgrade that replaces `app.appserver.custom_settings`.

## Demo reset / backend sync time out against public VIP
Symptom:
- Demo org reset fails in `reprovisioning`.
- Worker logs show timeouts to public hostnames such as:
  - `https://skyforge-fwd.local.forwardnetworks.com`
  - `https://skyforge.local.forwardnetworks.com/git/api/v1`
- Errors include `i/o timeout`, `context deadline exceeded`, or `could not resolve host`.

Typical cause:
- Skyforge backend pods are using public Forward or Gitea hostnames for server-side workflows.
- In some clusters the pods cannot resolve those names internally, or should not hairpin through the Gateway VIP.

Recommended config:
- `skyforge.forward.baseUrl: https://fwd-appserver.forward.svc:8443`
- `skyforge.gitea.apiUrl: http://gitea.skyforge.svc.cluster.local:3000/api/v1`
- `skyforge.gitea.url: /git`

This is not only for API calls. Demo seed raw file reads and Git LFS object downloads are also derived from the configured server-side Gitea base, so leaving workers on the public `/git` host can still fail later with a timeout against the external VIP.

Notes:
- `skyforge.forwardCluster.hostname` can stay public for browser access.
- `skyforge.gitea.url` can stay same-origin for browser links while `skyforge.gitea.apiUrl` stays internal for jobs and workers.

Checks:
```bash
kubectl -n forward get deploy fwd-appserver \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="appserver")].env[?(@.name=="APPSERVER_SETTINGS")].value}'; echo
curl -ksI https://skyforge-fwd.local.forwardnetworks.com/ | head -n 8
```

Expected:
- `APPSERVER_SETTINGS` contains `-Dforward.baseurl=https://skyforge-fwd.local.forwardnetworks.com`
- Forward root responds with a normal auth redirect (`location: /login`) instead of a malformed external URL.

Remediation:
```bash
kubectl -n forward set env deploy/fwd-appserver --containers=appserver \
  APPSERVER_SETTINGS='-Drestore.dir=/cbr/restore -Dforward.baseurl=https://skyforge-fwd.local.forwardnetworks.com'
kubectl -n forward rollout status deploy/fwd-appserver --timeout=10m
```

## Skyforge VIP answers ARP but VPN clients still time out on 443
Symptom:
- `skyforge.local.forwardnetworks.com` resolves to the reserved VIP (for example `10.128.16.80`).
- ARP for the VIP works from the VPN side.
- TCP `443` to the VIP still times out for VPN users, while some in-cluster or node-local checks keep working.

Typical cause:
- The current L2 lease holder node has a broken Cilium Gateway datapath for the Skyforge VIP.
- In the observed failure mode, the node receives external SYNs for the VIP but does not redirect them into the current Envoy listener, so the connection never reaches the Gateway listener.

Checks:
```bash
kubectl get lease -n kube-system cilium-l2announce-skyforge-cilium-gateway-skyforge -o yaml | grep holderIdentity
kubectl -n kube-system exec ds/cilium -- cilium-dbg shell -- db/show l2-announce
curl -skI --resolve skyforge.local.forwardnetworks.com:443:10.128.16.80 \
  https://skyforge.local.forwardnetworks.com/
```

Repair:
- On the broken holder node, remove stale `OLD_CILIUM_*` iptables backup chains.
- Restart that node's `cilium` pod so the datapath rebuilds from clean state.
- Re-test by forcing the L2 lease onto that node and verifying:
  - `curl -skI --resolve skyforge.local.forwardnetworks.com:443:10.128.16.80 https://skyforge.local.forwardnetworks.com/`

Temporary mitigation:
- If the holder path must stay available during repair, temporarily pin the L2
  announcement policy to known-good nodes by adding `spec.nodeSelector` to:
  - `deploy/skyforge-gateway-vip-policy-local.yaml`
- Remove that selector again after the broken node is repaired and verified.

Persistence:
- `scripts/install-single-node.sh` and `scripts/deploy-skyforge-prod-safe.sh`
  apply `deploy/skyforge-gateway-vip-policy-local.yaml` after Helm so the local
  environment keeps a repo-managed source of truth for the VIP announcement
  policy.

## Kubernetes API VIP is flaky on `10.128.16.82`
Symptom:
- `https://10.128.16.82:6443/version` intermittently times out or returns `000`
  while direct control-plane node IPs still answer.

Typical cause:
- The API VIP is not running under the repo-managed `kube-vip` DaemonSet on all
  control-plane nodes.
- A legacy Cilium-backed API VIP path (`Service/kubernetes-vip`,
  `CiliumLoadBalancerIPPool/skyforge-api-vip`,
  `CiliumL2AnnouncementPolicy/skyforge-api-vip`) still exists and is stealing
  ownership of `10.128.16.82`.

Checks:
```bash
kubectl -n kube-system get ds,pods -l app.kubernetes.io/name=kube-vip-api -o wide
kubectl -n kube-system get svc kubernetes-vip endpoints kubernetes-vip
kubectl get ciliuml2announcementpolicy.cilium.io skyforge-api-vip
kubectl get ciliumloadbalancerippool.cilium.io skyforge-api-vip
curl -sk --max-time 2 -o /dev/null -w '%{http_code} %{time_total}\n' \
  https://10.128.16.82:6443/version
```

Repair:
- Remove the legacy Cilium-backed API VIP resources if they are still present:
```bash
kubectl -n kube-system delete service kubernetes-vip endpoints kubernetes-vip --ignore-not-found=true
kubectl delete ciliuml2announcementpolicy.cilium.io skyforge-api-vip --ignore-not-found=true
kubectl delete ciliumloadbalancerippool.cilium.io skyforge-api-vip --ignore-not-found=true
kubectl -n kube-system delete cronjob kubernetes-vip-endpoints-sync \
  configmap kubernetes-vip-endpoints-sync \
  serviceaccount kubernetes-vip-endpoints-sync --ignore-not-found=true
kubectl delete clusterrole kubernetes-vip-endpoints-sync \
  clusterrolebinding kubernetes-vip-endpoints-sync --ignore-not-found=true
```
- Re-apply the repo-managed kube-vip manifest:
```bash
kubectl apply -f deploy/skyforge-api-vip-local.yaml
```

Persistence:
- `deploy/skyforge-api-vip-local.yaml` is the source of truth for:
  - `ServiceAccount/kube-vip`
  - `ClusterRole/system:kube-vip-role`
  - `ClusterRoleBinding/system:kube-vip-binding`
  - `DaemonSet/kube-vip-api`
- `scripts/install-single-node.sh` and `scripts/deploy-skyforge-prod-safe.sh`
  both delete the legacy Cilium-backed API VIP resources before applying the
  repo-managed kube-vip manifest after Helm.

Persistence:
- Keep `-Dforward.baseurl=...` in Forward Helm values under `app.appserver.custom_settings`.
- Skyforge overlays include this in:
  - `deploy/examples/values-forward-local-k3s.yaml`
  - `deploy/examples/values-forward-prod.yaml`
  - `deploy/examples/values-forward-prod-demo-fast.yaml`
  - `deploy/examples/values-forward-demo-fast.yaml`
- Skyforge bootstrap and prod-safe deploy automation also re-assert
  `fwd-appserver` `MEMORY_PROFILE=SHARED_CLUSTER`,
  `SHARED_CLUSTER_CONTAINER_MEMORY`, and
  `SHARED_CLUSTER_HEAP_MEMORY_PCT` after upstream Forward reconciliation, since
  the upstream `forward-local` release can drift back to `SINGLE_BOX`.
- `./scripts/deploy/local/integration-repair.sh post-helm`,
  `scripts/deploy-skyforge-prod-safe.sh`, and
  `scripts/recover-prod-after-reboot.sh` now re-apply the upstream worker
  runtime from `components/charts/skyforge/values-prod-skyforge-local.yaml` so
  `fwd-compute-worker` and `fwd-search-worker` keep their configured
  `MEMORY_PROFILE`, explicit heap caps, and pod memory request/limit settings
  before any repair-triggered worker restart. For the current local profile,
  both workers use `ISOLATED_WORKER` with explicit memory caps instead of the
  previous `SHARED_CLUSTER` split.

## Forward reprocess looks stuck or wildly overestimates ETA
When a snapshot reprocess appears stuck, profile the actual worker, DB, and node
behavior before changing cluster size. The UI ETA can stay pessimistic through a
compute-heavy phase and then correct sharply later.

Use the attach-first profiler:

```bash
python3 scripts/profile-forward-reprocess.py --sample-interval-seconds 30
```

See [forward-reprocess-profiling.md](forward-reprocess-profiling.md) for the
artifact format, interpretation rules, and the supported JVM vector-module
experiment path.

## Quick deploy is slow before the deployment even exists
Split quick deploy latency into two phases:

- synchronous request latency for `POST /api/quick-deploy/deploy`
- asynchronous run latency after the deployment record is created

Use the API deployment logs for the request path:

```bash
kubectl -n skyforge logs deploy/skyforge-server --since=15m | rg "quick deploy request"
```

Then inspect the resulting run via `/api/runs/<taskID>/lifecycle` and
`/api/runs/<taskID>/events` for the async half.

See [quick-deploy-profiling.md](quick-deploy-profiling.md) for the phase names,
interpretation, and the main optimization targets.

## Task queue scaling and `nsq` stability
Symptoms:
- queue depth grows during heavy deploy churn.
- operator attempts to scale `nsq` replicas to improve throughput.

Encore-native rule:
- keep `nsq` as a singleton (`replicas: 1`).
- do not scale standalone `nsqd` replicas behind one Service; that can partition queue delivery.

Scale path that is safe:
- increase `skyforge.worker.replicas`.
- enable/tune `skyforge.worker.autoscaling`.
- increase worker tuning (`interactiveConcurrency`, `backgroundConcurrency`, queue sizes).

Checks:
```bash
kubectl -n skyforge get deploy nsq skyforge-server-worker
kubectl -n skyforge get hpa skyforge-server-worker
curl -k https://skyforge.local.forwardnetworks.com/api/admin/tasks/diag
```

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
# Enterprise (default)
./scripts/build-push-skyforge-server.sh --tag <tag>

# OSS edition
./scripts/build-push-skyforge-server.sh --tag <tag> --edition oss
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

Operational safety rule:
- Do not leave Skyforge in a degraded public state during rollout work if a safe
  restore is available.
- Before a live Helm upgrade, Gateway API edit, or route reconcile that could
  impact the public hostname, announce the risky action and identify the restore
  path first.
- If the public hostname starts returning `404`/`5xx` unexpectedly during live
  work, pause feature changes and restore the public route/app path before
  continuing.
- If Helm is left in `pending-upgrade`, `pending-install`, or
  `pending-rollback`, clear the stuck release state before attempting more live
  changes.

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
- Verify the public site explicitly after Gateway/Helm changes:
  - `curl -sk https://skyforge.local.forwardnetworks.com/api/health`
  - `curl -sk -D - https://skyforge.local.forwardnetworks.com/ -o /tmp/skyforge-root.out`
  - confirm `/` returns the SPA entrypoint instead of an Envoy `404`
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
