# Kubernetes backup / restore (k3s single-node, local-path)

Pragmatic backup plan for single-node k3s with `local-path` storage.

For multi-node local-path clusters, prefer:
- `skyforge.backups.localSpread` to replicate backup artifacts onto worker-node local disks.
- `skyforge.backups.offsiteRaw` to rsync those artifacts to an external mounted path (for example Hetzner WireGuard volume).

## What to back up
1. k3s datastore
- sqlite: `/var/lib/rancher/k3s/server/db/state.db`
- etcd mode: use k3s etcd snapshots

2. PV data
- `/var/lib/rancher/k3s/storage/`

3. local deployment secrets
- `deploy/skyforge-secrets.yaml` (kept out of git)

## Backup
```bash
kubectl -n skyforge scale deploy --all --replicas=0

ts="$(date +%Y%m%d-%H%M%S)"
dest="/root/skyforge-backups/${ts}"
mkdir -p "${dest}"

if [ -f /var/lib/rancher/k3s/server/db/state.db ]; then
  cp -a /var/lib/rancher/k3s/server/db/state.db "${dest}/k3s-state.db"
fi

tar czf "${dest}/k3s-local-path-storage.tgz" -C /var/lib/rancher/k3s storage

kubectl -n skyforge scale deploy --all --replicas=1
```

## Restore
```bash
sudo systemctl stop k3s || true

src="/root/skyforge-backups/<timestamp>"
rm -rf /var/lib/rancher/k3s/storage
tar xzf "${src}/k3s-local-path-storage.tgz" -C /var/lib/rancher/k3s

if [ -f "${src}/k3s-state.db" ]; then
  cp -a "${src}/k3s-state.db" /var/lib/rancher/k3s/server/db/state.db
fi

sudo systemctl start k3s
kubectl get nodes
kubectl -n skyforge get pods
```
