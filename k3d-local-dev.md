# Local k3d Dev Cluster (default-safe workflow)

Use this workflow for day-to-day development to avoid accidental prod operations.

## Recreate local cluster

```bash
cd /home/captainpacket/src/skyforge
./scripts/k3d-recreate-skyforge.sh
```

What it does:
- deletes existing `k3d` clusters named `skyforge` (and legacy `skyforge-qa` by default),
- creates `k3d-skyforge` with prod-like k3s/Cilium settings,
- uses k3s image `rancher/k3s:v1.35.2-k3s1` by default (`SKYFORGE_K3S_IMAGE` override),
- writes kubeconfig to `.kubeconfig-skyforge`,
- sets context to `k3d-skyforge`,
- by default runs:
- phase 1: `./scripts/deploy-skyforge-local.sh --no-verify`
  - phase 2: `./scripts/bootstrap-forward-local.sh`
  - phase 3: `./scripts/verify-k3d-local-stack.sh` (aggregate report + final pass/fail)
  - `deploy-skyforge-local.sh` now auto-bootstraps Forward when
    `forward/fwd-appserver` is missing (`SKYFORGE_AUTO_BOOTSTRAP_FORWARD_IF_MISSING=true`)
- ensures `local-path` storage is usable by installing Rancher
  `local-path-provisioner` when needed (or reusing an existing valid one)
- prints periodic progress heartbeats during long-running phases (cluster create,
  Helm apply, rollout waits) so stalled waits are visible in CI/terminal logs
- if phase-1 local deploy fails, retries once automatically (default retry uses
  the same clean deploy args), so first-boot transient sequencing issues can recover

Opt out when needed:

```bash
SKYFORGE_AUTO_DEPLOY_LOCAL=false SKYFORGE_AUTO_BOOTSTRAP_FORWARD=false ./scripts/k3d-recreate-skyforge.sh
```

Skip phase-3 verification explicitly:

```bash
./scripts/k3d-recreate-skyforge.sh --no-verify
```

Tune progress heartbeat cadence:

```bash
SKYFORGE_PROGRESS_INTERVAL_SECONDS=5 ./scripts/k3d-recreate-skyforge.sh
```

## Deploy Skyforge locally

```bash
cd /home/captainpacket/src/skyforge
./scripts/deploy-skyforge-local.sh
```

Defaults:
- values base: `components/charts/skyforge/values-prod-skyforge-local.yaml`
- local overlay: `deploy/examples/values-k3d-dev.yaml`
- generated secrets: `.tmp/k3d-skyforge/skyforge-secrets.yaml`
- hostname: `skyforge.local.forwardnetworks.com`
- local auth login: `skyforge`
- local auth password: `skyforge`
- host exposure: loopback only (`127.0.0.1:80` / `127.0.0.1:443`)
- local ingress uses the same Cilium Gateway / Envoy path as other environments;
  there is no separate local NGINX frontdoor
- Gateway nodePort pinning is now chart-owned and declarative:
  `skyforge.gateway.localNodePorts.enabled=true` in local overlay runs a Helm
  hook Job that reconciles `cilium-gateway-skyforge` to stable
  `30080`/`30443` values so `k3d` host bindings stay deterministic
- `./scripts/deploy-skyforge-local.sh` now runs an automatic node-network
  resilience gate before and after Helm apply (`scripts/k8s-network-resilience.sh`);
  it probes service DNS/TCP from each Ready node and, on failure, restarts only
  that node's `cilium`/`cilium-envoy` pods before proceeding
- local deploy now explicitly waits for integration rollouts when present
  (`yaade`, `jira`, `rapid7`, `kibana`) and enforces `HTTPRoute`
  readiness for `skyforge-tools-extra` when that route exists
- local deploy now runs a dedicated ELK health gate after rollout
  (`kibana` service reachability probe with retries) before final verification
- local deploy now enforces both `vm.max_map_count=262144` and
  `fs.inotify.max_user_instances=64000` on k3d node containers before Helm apply
  (required by Elasticsearch bootstrap checks and KNE IOS-XR kernel constraints)
- Gitea Actions runner token reconciliation is chart-owned via a post-install/
  post-upgrade hook job (the deploy script no longer mutates that secret)
- deployment verification now uses an aggregate-fail contract via
  `scripts/verify-k3d-local-stack.sh` and writes a JSON report (default:
  `out/k3d-deploy-report-<timestamp>.json`)
  - verification now prints per-check progress/pass/fail lines so long probes are visible
- local deploy runs `scripts/post-deploy-smoke.sh` by default with bounded
  server smoke timeout (`SMOKE_SERVER_TIMEOUT_SECONDS`, default `240`)
  - disable only when needed: `RUN_POST_DEPLOY_SMOKE=false`
- KubeVirt NOS smoke matrix is available via:
  `SKYFORGE_SMOKE_PASSWORD=<admin-password> ./scripts/smoke-kubevirt-nos.sh`
  (runs netlab+KNE create/start/delete checks for all KubeVirt NOS smoke templates)

Add a hosts entry on the local workstation:

```text
127.0.0.1 skyforge.local.forwardnetworks.com
```

Authentication uses the same browser auth contract as other environments:
- `skyforge.auth.mode=local` makes the portal use direct local login via `/login/local` (`POST /api/login`)
- `skyforge.auth.mode=oidc` makes the portal use `/api/auth/oidc/login`

For local k3d, keep `skyforge.auth.mode=local` unless you are explicitly testing OIDC.

The local profile is now built as:
- prod-parity platform base values,
- a thin local overlay for local auth, loopback ingress, and staged additions.

This layering is enforced by:
- `scripts/check-k3d-parity.py`
- `components/docs/local-prod-parity-contract.md`

Current local parity target:
- `Coder`, `Gitea`, `NetBox`, `Nautobot`, `Yaade`, `clabernetes`, and the shared
  Envoy/Gateway path are enabled the same way they are in the prod-parity base
- `Forward` is no longer disabled in local values, but the local cluster still
  needs an actual `forward` stack bootstrapped if you want the Forward route and
  collector flow to be live end-to-end
- Forward ingress (`skyforge-fwd.local.forwardnetworks.com`) is now attached as
  an `HTTPRoute` in the `forward` namespace (parented to the shared `skyforge`
  Gateway), which avoids cross-namespace backend-ref resolution failures seen in
  Cilium when routing from a `skyforge`-namespace route to `forward/fwd-appserver`
- local deploy now skips rendering Forward DB credential secrets when operator-
  managed `postgres.fwd-pg-*.credentials` secrets already exist, preventing
  Helm upgrade conflicts during normal local upgrades
- local deploy now runs `scripts/deploy/local/integration-repair.sh` before and
  after Helm apply so Forward Postgres leaders are reconciled to the desired
  `postgres.fwd-pg-*.credentials` secrets on every deploy
- Forward observability UI routes (`/grafana`, `/prometheus`) are enabled in
  local overlay and currently route through `fwd-appserver`
  (`/monitoring`, `/prometheus`) rather than dedicated Grafana/Prometheus
  services
- local parity validation should be done through the shared Envoy/Gateway routes
  (`/git`, `/coder`, `/netbox`, `/nautobot`, `/api-testing`, `/infoblox`, `/jira`, `/rapid7`, `/dashboard/integrations`) rather
  than any separate frontdoor or localhost-only proxy layer

Bootstrap and upgrade are now separated:
- normal `./scripts/deploy-skyforge-local.sh` runs Helm upgrade/install, then
  runs aggregate verification (disable with `--no-verify`)
  - aggregate verification now includes a required blueprints readiness gate:
    authenticated `source=blueprints` netlab template listing must return at
    least one template before deploy is considered healthy
  - aggregate verification now includes a required ForwardAuth gateway check
    (`/api/auth/forwardauth/envoy`) before NetBox/Nautobot/Jira route probes so
    SSO/auth regressions fail early with a specific signal
  - gateway health checks accept `Programmed=False (AddressNotAssigned)` when
    `skyforge.gateway.addresses` is empty (k3d/nodeport mode), then rely on
    route probes for final readiness
- deploy now gates Helm apply with a machine-readable preflight contract:
  `scripts/deploy/local/preflight.sh`
- if Infoblox managed mode is enabled (`skyforge.infoblox.enabled=true` and
  `skyforge.infoblox.managed=true`), local deploy auto-installs KubeVirt/CDI
  prerequisites when the CRDs are missing
- if KEDA is enabled (`skyforge.keda.enabled=true`), local deploy auto-installs
  KEDA cluster-wide before Helm apply when `ScaledObject` CRDs are missing
- if KNE meshnet is enabled (`skyforge.kne.enabled=true`), Helm installs the
  vendored upstream meshnet manifests (CRDs + daemonset) using
  `skyforge.kne.meshnetMode` (`grpc` or `vxlan`)
- `db-provision` is chart-owned and runs as a Helm hook on install/upgrade
- use `SKYFORGE_REGENERATE_SECRETS=true` only when you are intentionally
  resetting local credentials/state
- blueprint reseed now defaults to the canonical push helper:
  - deploy wrapper calls `scripts/push-blueprints-to-gitea.sh` by default
  - helper tries route-first access (`/api/gitea/public`, `/git`, `/`) and then
    uses local `kubectl port-forward` to `svc/gitea` if needed
  - if route and port-forward are both unavailable, helper falls back to
    `scripts/reseed-blueprints-incluster.sh`
  - default mode is `SKYFORGE_RESEED_BLUEPRINTS_MODE=git`
    (`ipspace/netlab-examples`, normalized under `netlab/`)
  - optional local source mode:
    - `SKYFORGE_RESEED_BLUEPRINTS_MODE=local`
    - copies `components/blueprints` content as-is
  - git source controls:
    - `SKYFORGE_RESEED_BLUEPRINTS_GIT_URL=https://github.com/ipspace/netlab-examples.git`
    - `SKYFORGE_RESEED_BLUEPRINTS_GIT_REF=main`
  - set `SKYFORGE_RESEED_BLUEPRINTS_USE_PUSH_HELPER=false` to force the older
    in-cluster reseed path
- Forward support-user/org-default enforcement is delegated to
  `scripts/forward-enforce-support-defaults.sh`
- node-network resilience gate tuning (optional):
  - `SKYFORGE_NETWORK_RESILIENCE_ENABLE=true|false`
  - `SKYFORGE_NETWORK_RESILIENCE_STRICT=true|false`
  - `SKYFORGE_NETWORK_RESILIENCE_PRE_HELM_STRICT=true|false`
  - `SKYFORGE_NETWORK_RESILIENCE_POST_HELM_STRICT=true|false`
  - `SKYFORGE_NETWORK_RESILIENCE_PROBE_ATTEMPTS=<n>` (default: `5`)
  - `SKYFORGE_NETWORK_RESILIENCE_PROBE_TIMEOUT_SECONDS=<n>` (default: `20`)
  - `SKYFORGE_NETWORK_RESILIENCE_CILIUM_WAIT_TIMEOUT_SECONDS=<n>`
  - `SKYFORGE_NETWORK_RESILIENCE_NODE_NAME_REGEX=<regex>`
- CoreDNS upstream fix (k3d local, optional):
  - `SKYFORGE_COREDNS_UPSTREAM_FIX_ENABLE=true|false` (default `true`)
  - `SKYFORGE_COREDNS_UPSTREAMS="1.1.1.1 8.8.8.8"` (default shown)
  - applied before pre-helm resilience gate to avoid DNS egress failures from
    CoreDNS forwarding to unreachable host resolvers in some local setups
- integration health gate tuning (optional):
  - `SKYFORGE_STRICT_INTEGRATION_HEALTH=true|false`
  - `SKYFORGE_AUTO_INSTALL_KEDA=true|false`
  - when `skyforge.kne.enabled=true`, post-helm health requires:
    - CRD `topologies.networkop.co.uk`
    - wire CRD by mode:
      - `gwirekobjs.networkop.co.uk` for `meshnetMode=grpc`
      - `wirekobjs.networkop.co.uk` for `meshnetMode=vxlan`
    - `meshnet` daemonset rollout in namespace `meshnet`
  - `SKYFORGE_INFOBLOX_HEALTH_STRICT=true|false` (default `false`; when `true`, Infoblox HTTPS must be reachable or deploy fails)
  - `SKYFORGE_ELK_HEALTH_ATTEMPTS=<n>`
  - `SKYFORGE_ELK_HEALTH_SLEEP_SECONDS=<n>`
- ngrok public tunnel (optional, still routed through Cilium Gateway API):
  - set `SKYFORGE_ENABLE_NGROK=true` for deploy-time enable, or set
    `skyforge.publicTunnel.ngrok.enabled=true` in values
  - provide token at deploy time with `SKYFORGE_NGROK_AUTHTOKEN=<token>`
  - when enabled via `SKYFORGE_ENABLE_NGROK=true`, local deploy forces:
    - `skyforge.publicTunnel.ngrok.hostNetwork=true`
    - `skyforge.publicTunnel.ngrok.dnsPolicy=Default`
    - `skyforge.publicTunnel.ngrok.targetAddress=k3d-<cluster>-server-0:30080`
    - `skyforge.gateway.additionalHostnames[0]=*.ngrok-free.dev`
  - chart-level controls (optional):
    - `skyforge.publicTunnel.ngrok.hostNetwork=true|false`
    - `skyforge.publicTunnel.ngrok.dnsPolicy=<policy>`
    - `skyforge.publicTunnel.ngrok.targetAddress=<host:port>`
  - optional secret name/key overrides:
    - `SKYFORGE_NGROK_AUTHTOKEN_SECRET_NAME=<name>`
    - `SKYFORGE_NGROK_AUTHTOKEN_SECRET_KEY=<key>`
- aggregate verification ELK probe tuning (optional):
  - `SKYFORGE_VERIFY_ELK_PROBE_ATTEMPTS=<n>`
  - `SKYFORGE_VERIFY_ELK_PROBE_SLEEP_SECONDS=<n>`
- k3d phase-1 deploy retry tuning (optional):
  - `SKYFORGE_DEPLOY_RETRY_ON_FAILURE=true|false`
- explicit repair entrypoint (not part of normal deploy):
  - `./scripts/deploy/local/integration-repair.sh pre-helm`
  - `./scripts/deploy/local/integration-repair.sh post-helm`
  - toggle specific actions with env flags:
    - `SKYFORGE_RECREATE_FORWARD_DB_SECRETS=true`
    - `SKYFORGE_FORWARD_RECONCILE_DB_AUTH=true|false`
    - `SKYFORGE_RAPID7_AUTO_RESET_BROKEN_HOME=true`

- Jira visibility in the side-nav can be enabled with
  `skyforge.jira.enabled=true` in the local overlay to expose
  `/jira` via a direct in-cluster service route (`skyforge.jira.serviceName`).
  For local all-in-cluster bring-up, set `skyforge.jira.managed=true`.

- Rapid7 visibility in the side-nav can be enabled with
  `skyforge.rapid7.enabled=true` in the local overlay to expose
  `/rapid7` via a direct in-cluster service route (`skyforge.rapid7.serviceName`).
  For local all-in-cluster bring-up, set `skyforge.rapid7.managed=true`.

- ELK visibility in the side-nav can be enabled with
  `skyforge.elk.enabled=true` and `skyforge.elk.managed=true` in the local
  overlay to expose `/elk` via an in-cluster Kibana service (`kibana:5601`).

The same local profile now supports the KubeVirt-backed Infoblox appliance via
the shared Gateway path:
- browser path: `https://skyforge.local.forwardnetworks.com/infoblox`
- in-cluster service target: `https://infoblox:443`
- operator bootstrap helper: `scripts/infoblox-bootstrap-console.sh`

The preferred local implementation is managed KubeVirt:
- set `skyforge.infoblox.managed=true`
- set `skyforge.infoblox.image` to a KubeVirt containerDisk image
- local k3d should keep the appliance in its expected multi-NIC shape:
  - `skyforge.infoblox.vm.podNetworkBinding=bridge`
  - `skyforge.infoblox.vm.managementInterfaceModel=virtio`
  - `skyforge.infoblox.vm.auxiliaryInterfaceModel=virtio`
  - `skyforge.infoblox.vm.multus.enabled=true`
  - `skyforge.infoblox.vm.multus.createNADs=true`
- enable VM lifecycle policy for resource savings and periodic reseed:
  - `skyforge.infoblox.lifecycle.enabled=true`
  - `skyforge.infoblox.lifecycle.autoStop.enabled=true`
  - `skyforge.infoblox.lifecycle.autoStop.maxIdleMinutes=<minutes>`
  - `skyforge.infoblox.lifecycle.autoStop.maxRunMinutes=<minutes>`
  - `skyforge.infoblox.lifecycle.reseed.enabled=true`
  - `skyforge.infoblox.lifecycle.reseed.resetAfterDays=60`
  - `skyforge.infoblox.lifecycle.license.enabled=true`
- keep route target on `skyforge.infoblox.serviceName` (default `infoblox`) and
  `skyforge.infoblox.servicePort` (default `443`)
- local k3d should route `/infoblox` directly to the managed KubeVirt Service;
  the older LAN-side proxy path is only a temporary fallback and should remain
  disabled in normal local values
- build/push a containerDisk from a local qcow2 with:
  `scripts/build-kubevirt-containerdisk-from-qcow2.sh --src-qcow2 <path> --dst <ghcr-image> --push`

### Infoblox first-boot bootstrap (network + temp license)

After first boot (or after a lifecycle reseed), the appliance may require
bootstrap initialization before HTTPS is reachable. Lifecycle now includes a
best-effort in-cluster temp-license reconcile CronJob. If it still cannot clear
the licensing prompts, use the operator helper below.

Automated (best-effort) bootstrap:

Run:

```bash
cd /home/captainpacket/src/skyforge
./scripts/infoblox-bootstrap-console.sh --auto
```

If auto mode cannot complete licensing prompts reliably, use interactive mode:

```bash
cd /home/captainpacket/src/skyforge
./scripts/infoblox-bootstrap-console.sh --interactive
```

Inside interactive console:
- run `set network` to confirm/adjust management IP/gateway for your cluster path
- run `set temp_license` and enable required eval services (Grid/DNS/DHCP as needed)

Then verify service from inside cluster:

```bash
kubectl -n skyforge run netdiag-ibx --image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet -- \
  sh -lc 'curl -k -sS -m 10 -o /dev/null -w "%{http_code}\n" https://infoblox'
```

Infoblox bootstrap automation is opt-in when HTTPS remains unreachable after VM restart:

```bash
SKYFORGE_INFOBLOX_AUTO_BOOTSTRAP=true ./scripts/deploy-skyforge-local.sh
```

Legacy fallback is still available for external appliances:
- enable `skyforge.infoblox.serviceAlias.enabled=true` and set
  `skyforge.infoblox.upstreamHost`/`upstreamPort`.

If `~/.docker/config.json` exists, the script also creates `ghcr-pull` in the `skyforge` namespace.

Clabernetes local image behavior is deterministic by default in local deploys:

- `SKYFORGE_CLABERNETES_BUILD_LOCAL_IMAGES=true` (default): build manager/launcher from `vendor/clabernetes` and import into k3d before Helm apply.
- `SKYFORGE_CLABERNETES_MANAGER_IMAGE` (default `skyforge-clabernetes-manager:local-dev`)
- `SKYFORGE_CLABERNETES_LAUNCHER_IMAGE` (default `skyforge-clabernetes-launcher:local-dev`)
- `SKYFORGE_CLABERNETES_SOURCE_DIR` (default `vendor/clabernetes`)
- `SKYFORGE_K3D_CLUSTER` (default `skyforge`)

Disable local image build only when intentionally testing published images:

```bash
SKYFORGE_CLABERNETES_BUILD_LOCAL_IMAGES=false ./scripts/deploy-skyforge-local.sh
```

Override the local login only when needed:

```bash
SKYFORGE_ADMIN_USER=myuser SKYFORGE_ADMIN_PASS='mypassword' ./scripts/deploy-skyforge-local.sh
```

Force fresh local secrets generation when you want a full reset:

```bash
SKYFORGE_REGENERATE_SECRETS=true ./scripts/deploy-skyforge-local.sh
```

## Bootstrap Forward locally

Skyforge local parity expects a real Forward stack in namespace `forward`.
Bootstrap it with the upstream chart wrapper in this repo:

```bash
cd /home/captainpacket/src/skyforge
./scripts/bootstrap-forward-local.sh
```

Defaults:
- Forward repo: `~/src/fwd`
- chart: `ops/kubernetes/fwd-helm`
- namespace: `forward`
- local bootstrap pins `fwd-cbr-agent` to 1 replica and disables `fwd-autopilot`
  by default (`SKYFORGE_FORWARD_ENABLE_AUTOPILOT=false`) to avoid unschedulable
  local-path PVC fanout in small k3d clusters.
- release: `forward-local`
- registry: `ghcr.io/forwardnetworks/forward`
- image tag: `26.2.4-02`
- local storage class: `local-path`
- shared-cluster PVC mode with Skyforge-owned ingress

Important:
- the wrapper intentionally suppresses the embedded Forward nginx ingress path;
  Skyforge Gateway/Envoy remains the only external ingress model locally
- the wrapper pre-applies the Zalando Postgres operator CRDs because the
  upstream chart keeps them under normal templates instead of `crds/`
- the wrapper stamps the local `k3d` nodes with the Forward scheduling labels
  expected by the upstream chart (`fwd-master`, `fwd-monitoring`,
  `fwd-compute-worker`, `fwd-search-worker`) before install
- after the Helm install, the wrapper patches the local appserver and
  backend-master pod templates with the `forwardnetworks.com/scratch-group`
  label so the in-cluster collector can co-locate the way the upstream
  collector deployment expects
- the wrapper now explicitly reconciles `pvc-fwd-collector` and waits for it to
  bind before waiting on the collector rollout; this prevents pending collector
  pods after reinstall paths where the PVC delete/recreate timing races
- by default the wrapper normalizes the local on-prem org state to
  `ORG_TYPE=INTERNAL` and `ENFORCE_LICENSING=false` after core services come up;
  this avoids restricted-mode behavior in the local all-in-one cluster
- the support user `forward` is enabled by default when org defaults are
  applied; set `SKYFORGE_FORWARD_ENABLE_SUPPORT_USER=false` if you need it
  disabled for a specific run
- support credential bootstrap is deterministic: local bootstrap first tries the
  saved `forward/forward-support-credentials` secret, falls back to
  `forward/forward`, then rotates away from the default password and persists
  the new random password back into `forward/forward-support-credentials`
- valid GHCR credentials for the mirrored Forward runtime images must already
  exist in `~/.docker/config.json`; the script does a manifest preflight and
  fails fast if `ghcr.io/forwardnetworks/forward` is not accessible

Mirror the airgap package into GHCR first:

```bash
cd /home/captainpacket/src/skyforge
./scripts/mirror-forward-package-to-ghcr.sh \
  ~/Downloads/forward-app-26.2.4-02.package
```

The mirror script publishes:
- app images to `ghcr.io/forwardnetworks/forward/*`
- shared images such as `local-volume-provisioner-fwd` to
  `ghcr.io/forwardnetworks/shared/*`

Useful overrides:

```bash
SKYFORGE_FORWARD_IMAGE_VERSION=<tag> ./scripts/bootstrap-forward-local.sh
SKYFORGE_FORWARD_REGISTRY=<registry> ./scripts/bootstrap-forward-local.sh
SKYFORGE_FORWARD_SKIP_IMAGE_PREFLIGHT=true ./scripts/bootstrap-forward-local.sh
SKYFORGE_FORWARD_CLEANUP_ON_FAILURE=true ./scripts/bootstrap-forward-local.sh
SKYFORGE_FORWARD_APPLY_SUPPORT_DEFAULTS=false ./scripts/bootstrap-forward-local.sh
SKYFORGE_FORWARD_ENABLE_SUPPORT_USER=true ./scripts/bootstrap-forward-local.sh
SKYFORGE_FORWARD_ROTATE_SUPPORT_PASSWORD=auto ./scripts/bootstrap-forward-local.sh
SKYFORGE_FORWARD_COLLECTOR_PASSWORD=admin ./scripts/bootstrap-forward-local.sh
```

By default, a failed local Forward bootstrap now preserves the Helm release and
workloads for debugging. Set `SKYFORGE_FORWARD_CLEANUP_ON_FAILURE=true` only if
you explicitly want the wrapper to uninstall a failed `pending-*` release.

`bootstrap-forward-local.sh` now also ensures `forward/collector.credentials`
exists (key: `password`) before applying Helm, so `fwd-collector` can start on
clean cluster rebuilds.

## Required local context

Operational scripts now default to `.kubeconfig-skyforge` and require context `k3d-skyforge`:
- `scripts/reset-skyforge.sh`
- `scripts/verify-install.sh`
- `scripts/prepull-images-k8s.sh`
- `scripts/push-blueprints-to-gitea.sh`
- `scripts/install-kubevirt-local.sh`
- `scripts/reseed-blueprints-incluster.sh`
- `scripts/forward-enforce-support-defaults.sh`
- `scripts/deploy/local/preflight.sh`
- `scripts/deploy/local/wait-rollout.sh`
- `scripts/deploy/local/wait-httproute.sh`
- `scripts/deploy/local/integration-health.sh`
- `scripts/deploy/local/integration-repair.sh`

If context is prod-like or non-local, scripts fail fast.

## Intentional overrides

Only use these for deliberate non-local operations:
- `SKYFORGE_ALLOW_NON_LOCAL_CONTEXT=true`
- `SKYFORGE_ALLOW_PROD_CONTEXT=true`

Production deploy remains blocked by default and now requires:

```bash
SKYFORGE_ALLOW_PROD_DEPLOY=true ./scripts/deploy-skyforge-prod-safe.sh
```

## Optional: enable KubeVirt locally

Use this only when you are validating VM-backed integrations or KubeVirt-backed
NOS paths. It installs:
- Multus plus the standard secondary CNI plugins on the local `k3d` nodes,
- KubeVirt with software emulation enabled by default for local `k3d`,
- CDI for disk import workflows,
- a CDI upload storage class (default `local-path`),
- `virtctl` into `~/.local/bin`,
- a small smoke VM to prove VM scheduling, networking, and serial console.

```bash
cd /home/captainpacket/src/skyforge
./scripts/install-kubevirt-local.sh
```

Local defaults:
- KubeVirt version: latest upstream stable
- CDI version: `v1.64.0`
- Multus version: `v4.1.3`
- CNI plugins version: `v1.6.2`
- KubeVirt emulation: enabled (`SKYFORGE_KUBEVIRT_USE_EMULATION=true`)
- smoke VM: `default/kubevirt-smoke`

The script is guarded the same way as other local workflows:
- uses `.kubeconfig-skyforge`
- requires context `k3d-skyforge`
- refuses prod-like contexts unless explicitly overridden

After install, basic console validation is:

```bash
export KUBECONFIG=/home/captainpacket/src/skyforge/.kubeconfig-skyforge
~/.local/bin/virtctl console -n default kubevirt-smoke
```

The public smoke image prints a login prompt on the serial console. That is the
minimum proof that VM-backed integrations such as Infoblox can run in the local
cluster before adding Skyforge lifecycle wiring around them.
