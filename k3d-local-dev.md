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
- writes kubeconfig to `.kubeconfig-skyforge`,
- sets context to `k3d-skyforge`,
- by default runs:
  - `./scripts/deploy-skyforge-local.sh`
  - `./scripts/bootstrap-forward-local.sh`

Opt out when needed:

```bash
SKYFORGE_AUTO_DEPLOY_LOCAL=false SKYFORGE_AUTO_BOOTSTRAP_FORWARD=false ./scripts/k3d-recreate-skyforge.sh
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
- `./scripts/deploy-skyforge-local.sh` pins the generated
  `cilium-gateway-skyforge` Service to stable NodePorts `30080` and `30443`
  so the `k3d` host bindings remain deterministic
- local deploy recreates the ephemeral `gitea-actions-runner-token` secret after
  Gitea is healthy so the local Actions runner stays aligned with the live Gitea instance
- if runner-token reconciliation fails because the embedded Gitea DB credentials
  drifted, the deploy now warns and continues; this no longer marks an otherwise
  healthy local rollout as failed

Add a hosts entry on the local workstation:

```text
127.0.0.1 skyforge.local.forwardnetworks.com
```

Authentication uses the same browser auth contract as other environments:
- `skyforge.auth.mode=password` makes the portal use direct `POST /api/login`
- `skyforge.auth.mode=oidc` makes the portal use `/api/oidc/login`

For local k3d, keep `skyforge.auth.mode=password` unless you are explicitly testing OIDC.

The local profile is now built as:
- prod-parity platform base values,
- a thin local overlay for password auth, loopback ingress, and staged additions.

This layering is enforced by:
- `scripts/check-k3d-parity.py`
- `components/docs/local-prod-parity-contract.md`

Current local parity target:
- `Coder`, `Gitea`, `NetBox`, `Nautobot`, `Yaade`, `clabernetes`, and the shared
  Envoy/Gateway path are enabled the same way they are in the prod-parity base
- `Forward` is no longer disabled in local values, but the local cluster still
  needs an actual `forward` stack bootstrapped if you want the Forward route and
  collector flow to be live end-to-end
- local parity validation should be done through the shared Envoy/Gateway routes
  (`/git`, `/coder`, `/netbox`, `/nautobot`, `/api-testing`, `/infoblox`) rather
  than any separate frontdoor or localhost-only proxy layer

Bootstrap and upgrade are now separated:
- normal `./scripts/deploy-skyforge-local.sh` runs a Helm upgrade/install only
- `db-provision` is run only when local secrets are regenerated or you explicitly
  set `SKYFORGE_BOOTSTRAP_DATABASES=true`
- use `SKYFORGE_REGENERATE_SECRETS=true` only when you are intentionally
  resetting local credentials/state

The same local profile now supports the KubeVirt-backed Infoblox appliance via
the shared Envoy ingress path:
- browser path: `https://skyforge.local.forwardnetworks.com/infoblox`
- in-cluster raw service: `http://infoblox-proxy:8080`

The current local implementation assumes:
- the Infoblox VM is already running under KubeVirt,
- `LAN1` is reachable at `192.168.1.2`,
- the raw `infoblox-proxy` pod is attached to the `infoblox-lan1` Multus
  network and pinned to the same node as the VM.

If `~/.docker/config.json` exists, the script also creates `ghcr-pull` in the `skyforge` namespace.

Override the local login only when needed:

```bash
SKYFORGE_ADMIN_USER=myuser SKYFORGE_ADMIN_PASS='mypassword' ./scripts/deploy-skyforge-local.sh
```

Force fresh local secrets generation when you want a full reset:

```bash
SKYFORGE_REGENERATE_SECRETS=true ./scripts/deploy-skyforge-local.sh
```

Force database/bootstrap reconciliation without regenerating secrets:

```bash
SKYFORGE_BOOTSTRAP_DATABASES=true ./scripts/deploy-skyforge-local.sh
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
- release: `forward-local`
- registry: `ghcr.io/forwardnetworks/forward`
- image tag: `26.2.2-01`
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
- valid GHCR credentials for the mirrored Forward runtime images must already
  exist in `~/.docker/config.json`; the script does a manifest preflight and
  fails fast if `ghcr.io/forwardnetworks/forward` is not accessible

Mirror the airgap package into GHCR first:

```bash
cd /home/captainpacket/src/skyforge
./scripts/mirror-forward-package-to-ghcr.sh \
  ~/Downloads/forward-app-26.2.2-01.package
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
```

By default, a failed local Forward bootstrap now preserves the Helm release and
workloads for debugging. Set `SKYFORGE_FORWARD_CLEANUP_ON_FAILURE=true` only if
you explicitly want the wrapper to uninstall a failed `pending-*` release.

## Required local context

Operational scripts now default to `.kubeconfig-skyforge` and require context `k3d-skyforge`:
- `scripts/reset-skyforge.sh`
- `scripts/verify-install.sh`
- `scripts/prepull-images-k8s.sh`
- `scripts/push-blueprints-to-gitea.sh`
- `scripts/install-kubevirt-local.sh`

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
- KubeVirt on KVM by default for local `k3d` hosts that expose `/dev/kvm`,
- CDI for disk import workflows,
- an immediate-binding storage class `local-path-immediate` for CDI uploads,
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
- KubeVirt emulation: disabled (`SKYFORGE_KUBEVIRT_USE_EMULATION=false`)
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
