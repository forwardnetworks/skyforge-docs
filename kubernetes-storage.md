# Kubernetes storage (Skyforge on k3s)

Skyforge currently targets **single-node k3s** with the default `local-path` StorageClass.

## Default: local-path (recommended for now)
- PVs live under `/var/lib/rancher/k3s/storage/` on the node.
- This is simple and works well for a single node.
- Backup/restore is handled by `docs/kubernetes-backup.md`.

## Multi-node local-path posture
- Keep primary state on local-path for low overhead and predictable performance.
- Use `skyforge.backups.localSpread` to replicate backup artifacts onto worker-node local disks.
- Use `skyforge.backups.offsiteRaw` for rsync copy to an external mounted destination (for example Hetzner WireGuard volume).
