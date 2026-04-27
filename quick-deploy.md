# Quick Deploy Workflow

This page documents the simplified deployment path at `/dashboard/deployments/quick`.

## Scope

- Deployment family/engine: `kne` / `netlab` only.
- Cluster prerequisite: the Skyforge release must enable `skyforge.kne`,
  which installs the in-cluster KNE API surface (`networkop.co.uk/v1beta1`)
  used by quick-deploy preflight. On Cilium clusters, Multus must be present
  and `kube-system/cilium-config` must set `cni-exclusive: "false"` so meshnet
  remains in the pod CNI chain.
- Container-lab host CNI contract: quick deploy container topologies rely on an
  active `/etc/cni/net.d/00-meshnet.conflist` on the worker host. If that file
  is absent, pods come up with only `eth0` and stall in `Connected 1 interfaces
  out of N`.
- K3s agent-node variant: on K3s worker nodes the active kubelet CNI path can be
  `/var/lib/rancher/k3s/agent/etc/cni/net.d` instead of `/etc/cni/net.d`.
  Guardrails and manual repairs must check both paths, or the host can look
  healthy while new pods still come up with only `eth0`.
- Environment install default: `scripts/deploy-skyforge-env.sh qa` should use
  `deploy/skyforge-values-qa.yaml` unless the caller overrides `SKYFORGE_ENV_VALUES`.
- Post-install host CNI contract: after the `meshnet` DaemonSet is up, rollout
  guardrails must restore `/etc/cni/net.d/00-meshnet.conflist` if Cilium or a
  prior repair renamed it away, and rewrite
  `/etc/cni/net.d/multus.d/multus.kubeconfig` to a reachable control-plane
  endpoint rather than an unreachable ClusterIP.
- Template source: curated Netlab blueprints managed by an admin catalog.
  - Default catalog focuses on EOS technology demos (EVPN, MPLS, BGP, VRF).
  - Default template files map to `netlab/*/topology.yml` from `skyforge/blueprints`.
  - Admin catalog saves are validated against live blueprint template index entries to prevent drift.
  - Tags are stored on admin catalog entries and are exposed as Launch Lab
    filters. Keep launch-facing tags sparse: known curated blueprint launchers
    use `curated`, Skyforge training labs use `training`, and all other public
    labs should remain untagged until an operator explicitly curates them.
  - Quick-deploy candidate topologies should omit top-level `provider` and
    EOS `defaults.device` so they inherit `provider: kne` and `device: eos`
    from Skyforge runtime defaults. Explicit non-KNE providers and non-EOS
    defaults should remain regular blueprints unless separately validated.
- Forward: always uses in-app Forward (`https://fwd-appserver.forward.svc.cluster.local`)
  with per-user tenant credentials + API token.
  - Skyforge ensures the user has a Forward org user/password.
  - Skyforge ensures API token `skyforge` exists for that user.
  - Token `accessKey` + `secret` are stored as the managed in-cluster collector
    credential for that user.
- Lease presets: `4h`, `8h`, `24h`, `72h` (default `24h`).

## Catalog source contract

Quick Deploy is intentionally tag/template driven. It must not expose a
free-form Git repository picker in the launch flow.

Eligible sources:

- Stored/default admin catalog entries.
- Public Skyforge Gitea repositories discovered by the server.
- Public repository templates that are KNE-compatible and live under `netlab/`
  or `labs/`.
- Training labs from `craigjohnson/skyforge-training/labs`, tagged only with
  `training`.
- The six known-good blueprint launchers are tagged only with `curated`.
- Other public Gitea labs are eligible and visible but default to blank tags.

Public Gitea entries carry source metadata so operators can trace them without
turning the UI into a repo browser:

- `templateSource=custom`
- `templateRepo=<owner>/<repo>`
- `templatesDir=labs` or `templatesDir=netlab`

Individual users may deploy from private repositories through the regular
deployment/source workflows. Private user repositories are not eligible for
Quick Deploy.

Catalog verification:

```bash
curl -fsS -H "Cookie: <skyforge session>" \
  https://skyforge.dc.forwardnetworks.com/api/quick-deploy/catalog | \
  python3 -m json.tool
```

Expected:

- Stored/default labs are present.
- Public Skyforge Gitea labs are present.
- At least one `training` entry is sourced from
  `craigjohnson/skyforge-training`.
- Training and curated entries are filterable by topology tags, not by launch
  mode or a repo-selection UI.

Before promotion, a candidate topology must pass the static audit, synchronous
netlab validation, and real quick-deploy runtime certification.

## Flow

1. User selects a curated template card.
2. Skyforge upserts a managed Forward credential profile (`in-cluster forward`)
   for the current user from token `skyforge`.
3. Skyforge creates a deployment with family/engine `kne` / `netlab` and
   `forwardEnabled=true`.
   - Quick Deploy marks catalog-selected templates as prevalidated so the HTTP
     request creates the deployment row and queues work promptly. Regular
     deployment create/update paths still run synchronous template validation.
4. Skyforge writes deployment lease metadata via
   `PUT /api/users/:id/deployments/:deploymentID/lease`.
5. Skyforge queues deployment create action directly (with short retry on
   transient duplicate/cooldown no-op responses).

The create, lease, and enqueue stages run on a bounded server-side launch
context. A browser navigation, retry, or closed tab must not cancel the
in-cluster netlab validation job after the user has submitted the launch.

## Lease enforcement

- Lease metadata is stored in deployment config keys:
  - `leaseEnabled`
  - `leaseHours`
  - `leaseExpiresAt`
  - `leaseStoppedAt`
  - `leaseStopTaskId`
- Cron job `skyforge-deployment-leases` runs every 5 minutes.
- For expired leases, Skyforge queues a `kne/netlab` stop action and stamps
  `leaseStoppedAt` + `leaseStopTaskId`.

## Regular deployments

- The regular Deployments page (`/dashboard/deployments`) exposes per-deployment
  lifetime management for managed deployment families (`kne`, `terraform`).
- Non-admin users cannot disable lifetime expiry and are capped at `72h`.
- Admin users can select "No expiry".

## APIs

- `GET /api/users/:id/deployments/:deploymentID/lease`
- `PUT /api/users/:id/deployments/:deploymentID/lease`
- `GET /api/deployment-lifetime/policy`
- `GET /api/quick-deploy/catalog`
- `POST /api/quick-deploy/deploy`
- `GET /api/admin/quick-deploy/catalog`
- `PUT /api/admin/quick-deploy/catalog`
- `GET /api/admin/quick-deploy/template-options`
- `POST /internal/cron/deployments/leases` (private cron endpoint)

## Blueprint audit

Before promoting a topology, run the static audit against the blueprint source
that the admin catalog uses:

```bash
./scripts/audit-netlab-quick-deploys.py components/blueprints/netlab --format markdown
```

The audit is read-only. A `true` candidate still needs synchronous netlab
validation and a real quick-deploy runtime certification before it should be
saved in the admin catalog.
