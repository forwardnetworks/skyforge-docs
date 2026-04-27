---
harness_kind: completed-exec-plan
status: completed
legacy_source: HANDOFF-2026-04-11-designer-forward.md
converted_at: 2026-04-27
archived_at: 2026-04-27
environment: mixed
title: KNE Designer parity and Forward runtime recovery
systems_touched: KNE Designer, Forward runtime, Skyforge server/worker
verification: preserved in converted legacy body
current_truth: components/docs/kne-workflow.md; components/docs/netlab-kne.md; components/docs/storage-longhorn.md
superseded_assumptions: see the Harness conversion notes and body sections for stale local/k3d/prod context details
archive_note: historical evidence only; use current_truth for active guidance
---

# KNE Designer parity and Forward runtime recovery

> Archived evidence note: this body is retained for provenance only. Use the `current_truth` frontmatter and the completed-plan stub for active guidance.

# Skyforge Handoff - 2026-04-11

This handoff captures the current state of KNE Designer parity work and Forward runtime recovery as of **2026-04-11**.

## 1. Environment + Scope

- Workspace: `/home/captainpacket/src/skyforge`
- Active cluster namespaces:
  - `skyforge` (Skyforge API/worker)
  - `forward` (Forward stack)
- Primary runtime mode discussed/validated: KNE native path from Designer (`/deployments-designer/kne/from-yaml`), not netlab conversion path.

## 2. What Was Implemented (Code)

### 2.1 KNE native deploy path changes

Implemented and exercised native KNE deploy flow in server taskengine:

- Added native topology conversion + deploy helpers:
  - `components/server/internal/taskengine/kne_native_topology_yaml.go`
  - `components/server/internal/taskengine/kne_native_deploy_job.go`
  - `components/server/internal/taskengine/kne_native_topology_yaml_test.go`

- Updated runtime deployment execution path:
  - `components/server/internal/taskengine/kne_task_run_deploy_execute.go`
  - Now normalizes incoming Designer YAML to CLI topology and runs `kne_cli create` in-cluster job.

### 2.2 RBAC and topology normalization fixes

Fixed two concrete native-launch blockers discovered in live runs:

1. **RBAC escalation issue**
- Removed status-subresource grants causing forbidden role escalation (`topologies/status`, `gwirekobjs/status`) in runtime role creation path for the in-cluster job.

2. **`<nil>` link endpoint bug in topology conversion**
- Compact link parsing now uses safe empty-string conversion instead of `fmt.Sprintf("%v", nil)`.
- Prevented invalid link output like `a_node: <nil>`.

### 2.3 Pod label alignment + native-mode verification correction

Fixed false negatives during readiness/native verification:

- `components/server/internal/taskengine/kube_pods.go`
- Pod lookup now supports both label styles used by runtime pods:
  - `kne/topologyOwner=<runtime-ns>`
  - `topo=<runtime-ns>`

- Native-mode verification no longer requires a `kne-launcher` sidecar/container (actual running pods are valid without it in this runtime shape); it now validates topology node container presence.

- Added selector unit test:
  - `components/server/internal/taskengine/kube_pods_test.go`

## 3. Chart/Image Alignment

Chart values were aligned to the currently validated server/worker fix tag:

- `components/charts/skyforge/values.yaml`
- `components/charts/skyforge/values-prod-skyforge-local.yaml`
- `components/charts/skyforge/values-prod-recreate-20260314.yaml`

Current aligned tag in values files:
- `ghcr.io/forwardnetworks/skyforge-server:20260411-kne-native-deploy-r6`
- `ghcr.io/forwardnetworks/skyforge-server:20260411-kne-native-deploy-r6-worker`

## 4. Live Build/Deploy Evidence

### 4.1 Built + pushed tags during this effort

Progressive tags built/pushed while fixing blockers:
- `r4`, `r5`, `r6`

Final validated tag:
- `20260411-kne-native-deploy-r6`

### 4.2 Deployed runtime images currently running

Confirmed in `skyforge` namespace:
- `skyforge-server -> ...:20260411-kne-native-deploy-r6`
- `skyforge-server-worker -> ...:20260411-kne-native-deploy-r6-worker`

### 4.3 Known deploy-script caveat

`./scripts/deploy-skyforge-prod-safe.sh` repeatedly reaches a known unrelated Forward tail failure (support/auth post-steps), but **Skyforge server/worker rollout completes before that failure**. The script output repeatedly showed successful rollout for skyforge core before Forward tail warnings.

## 5. Designer Launch Validation (Live)

### 5.1 API used

- Login: `POST /api/auth/login`
- Launch from YAML:
  - `POST /api/users/1774010192-user-craigjohnson/deployments-designer/kne/from-yaml`

### 5.2 Key observed milestones

1. Initial failures were reproduced and resolved incrementally:
- invalid topology links (`<nil>` endpoints)
- runtime RBAC role escalation
- false native-mode/pod-selection failure

2. After final fixes (`r6`), a fresh deployment under `craigjohnson` succeeded:
- Deployment ID: `66c5b8e6-c06e-4f3f-b872-5d89065d85d0`
- Name: `cj-live-catalog-091831`
- Final status via deployments list API: `lastStatus: success`
- Node pods in runtime namespace were `Running`.

### 5.3 Important test-data caveat

Ad-hoc tests using `:latest` image tags failed because those tags are not pullable in current registry state. Use catalog-backed explicit tags.

Working sample images used in successful validation:
- `ghcr.io/forwardnetworks/kne/cisco_iol:17.16.01a-kne-r27`
- `ghcr.io/forwardnetworks/kne/cisco_iol_l2:17.16.01a-kne-r2`

## 6. Current Forward Status (at handoff time)

Forward in namespace `forward` is currently **not healthy**.

Unhealthy core deployments observed:
- `fwd-appserver` (CrashLoopBackOff in primary container)
- `fwd-backend-master` (CrashLoopBackOff)
- `fwd-compute-worker` (CrashLoopBackOff)
- `fwd-search-worker` (restart loop/unready)
- `fwd-collector` (Error)

Healthy supporting components observed:
- postgres clusters (`fwd-pg-*`) mostly healthy
- cbr agents/server healthy
- `fwd-nqe-assist` healthy

## 7. Forward Recovery Investigation Notes

- Stdout logs from failing containers currently show only memory-profile wrapper output and Java warnings, not complete root-cause stack traces.
- `describe pod` confirms repeated exits with code 1 / crash loops.
- Likely next diagnostic step is extracting richer process logs or startup script stderr from inside the primary container image/runtime (not yet completed in this handoff snapshot).

## 8. Git Working Tree Snapshot (relevant paths)

### Server
- Modified:
  - `components/server/internal/taskengine/kube_pods.go`
  - `components/server/internal/taskengine/kube_pods_test.go`
- New (uncommitted in this workspace snapshot):
  - `components/server/internal/taskengine/kne_native_topology_yaml.go`
  - `components/server/internal/taskengine/kne_native_deploy_job.go`
  - `components/server/internal/taskengine/kne_native_topology_yaml_test.go`

### Charts
- Modified:
  - `components/charts/skyforge/values.yaml`
  - `components/charts/skyforge/values-prod-skyforge-local.yaml`
  - `components/charts/skyforge/values-prod-recreate-20260314.yaml`

## 9. Recommended Next Steps on New Machine

1. Re-open repo and validate dirty tree state first:
- `git status --short`

2. Re-verify Skyforge core image rollout and Designer success path:
- check deployed images in `skyforge`
- run one API launch from `from-yaml` under `craigjohnson`
- confirm runtime namespace pods ready + deployment status `success`

3. Continue Forward recovery (runtime only if avoiding file changes):
- gather definitive startup failure traces from crashing Forward primary containers
- remediate via Helm values/runtime config/secret fixes only
- restart Forward deployments
- verify `skyforge-fwd` login/API health

4. After stabilization, create a clean commit set from the modified/new files listed above.

## 10. Handy Commands

### Check Skyforge server/worker images
```bash
kubectl -n skyforge get deploy skyforge-server skyforge-server-worker \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

### Check Forward high-level health
```bash
kubectl -n forward get deploy,statefulset,pods
```

### Run Designer launch (existing cookie/login flow)
```bash
curl -sk -b /tmp/skyforge-live.cookie -H 'content-type: application/json' \
  --data @/tmp/kne-live-catalog-req.json \
  https://skyforge.local.forwardnetworks.com/api/users/1774010192-user-craigjohnson/deployments-designer/kne/from-yaml
```

