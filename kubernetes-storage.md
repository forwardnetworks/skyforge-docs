# Kubernetes storage (Skyforge on k3s)

Skyforge currently targets **single-node k3s** with the default `local-path` StorageClass.

## Default: local-path (recommended for now)
- PVs live under `/var/lib/rancher/k3s/storage/` on the node.
- This is simple and works well for a single node.
- Backup/restore is handled by `docs/kubernetes-backup.md`.

## Optional: Longhorn
If you want CSI + replication/snapshots, Longhorn is the intended next step.

Repo support:
- `k8s/overlays/k3s-longhorn` (PVC/storage overlay)

Operational notes:
- Longhorn adds components and resource overhead; size the host accordingly.
- Prefer snapshot + off-node backup for disaster recovery.
