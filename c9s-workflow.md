# C9s (Clabernetes) workflow

Skyforge supports deploying labs into Kubernetes using **clabernetes** (referred to as **C9s** in the UI).

This is intended to let Skyforge scale “lab compute” horizontally by running labs as pods inside the k3s cluster (instead of SSHing to an external Containerlab/Netlab host).

## How it works

### 1) Containerlab → C9s (deployment type: `clabernetes`)

- User selects a **Containerlab topology** template (YAML) from either:
  - public blueprints (`blueprints/containerlab`), or
  - the user repo.
- Skyforge creates a `Topology` custom resource:
  - `apiVersion: clabernetes.containerlab.dev/v1alpha1`
  - `kind: Topology`
  - `spec.definition.containerlab: "<containerlab yaml>"`
- clabernetes reconciles the Topology and launches the node pods.

Notes:
- There is no separate “conversion” step required: clabernetes accepts the Containerlab YAML directly via `spec.definition.containerlab`.
- Skyforge places each user scope into its own Kubernetes namespace by default:
  `ws-<userScopeSlug>` (sanitized).

### 2) Netlab → C9s (deployment type: `netlab-c9s`)

Netlab-on-C9s uses Netlab only as a generator of Containerlab artifacts, then deploys those artifacts to Kubernetes via clabernetes:

1. Skyforge syncs the Netlab template folder and runs Netlab generation in-cluster
   via Kubernetes Job (`netlab-c9s` native mode). BYOS Netlab server mode is not
   used for this path.
2. Runs `netlab create` to generate:
   - `clab.yml`
   - `node_files/…` (startup configs and related files)
3. Exports the generated artifacts as a `containerlab-<deployment>.tar.gz` tarball.
4. Skyforge parses the tarball:
   - extracts `clab.yml`
   - extracts per-node `node_files/<node>/*`
5. Skyforge creates one ConfigMap per node containing that node’s `node_files`, labeled with:
   - `skyforge-c9s-topology=<topologyName>`
6. Skyforge creates a clabernetes `Topology` that mounts those ConfigMaps using `spec.deployment.filesFromConfigMap`.

This gives an end-to-end “Netlab template → k8s lab” path without needing an external Containerlab host.

## What’s still “phase 2” / future work

- Post-deploy configuration steps executed *after* the C9s topology becomes ready.
  - Linux nodes are configured by running the netlab-generated `node_files/<node>/{initial,routing}` scripts directly in-pod.
  - Network OS nodes are configured via startup configs mounted at boot time.
  - If we need additional post-up work in the future, it should be implemented in Go (worker/taskengine) rather than via Ansible jobs.

## Ops / prerequisites

- Helm: `values.yaml` has `skyforge.clabernetes.enabled` (experimental).
- RBAC: Skyforge server needs to be able to `get/list/create/update/delete`:
  - `topologies.clabernetes.containerlab.dev`
  - `configmaps`
  - `namespaces`

## Troubleshooting

- If `Topology` never becomes ready:
  - `kubectl -n <ns> get topologies`
  - `kubectl -n <ns> describe topology <name>`
  - check clabernetes manager logs: `kubectl -n skyforge logs deploy/clabernetes-manager`
- If node pods constantly restart (Deployment `kubectl.kubernetes.io/restartedAt` keeps changing):
  - root cause is usually the clabernetes controller thinking configs changed every reconcile.
  - ensure the clabernetes manager image is built with the “restart on config hash” fix (Skyforge tags around `20260119-restart-hash-*`).
- If you see `topology capture failed: Access Denied`:
  - the Skyforge worker stores topology graph artifacts in the `skyforge-files` bucket.
  - ensure the configured object-storage principal referenced by `SKYFORGE_OBJECT_STORAGE_ACCESS_KEY` has write access to `skyforge-files/*`.
- If Netlab-C9s deploy fails early:
  - confirm the Netlab server can run `netlab create` and produce `clab.yml` and `node_files/`.
