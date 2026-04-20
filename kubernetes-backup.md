# Kubernetes backup / restore (k3s)

Pragmatic backup plan for Skyforge k3s clusters.

The old single-node `local-path` snapshot flow remains a useful break-glass path,
but the intended multi-node posture is:

- Longhorn for critical PVCs
- local and off-cluster backup copies for stateful data
- application-consistent exports for Postgres-backed services

For multi-node clusters, prefer:

- `skyforge.backups.localSpread` to replicate object backup artifacts onto worker-node local disks
- `skyforge.backups.offsiteRaw` to mirror those local artifacts off-cluster from every eligible node
- `skyforge.backups.forwardRaw` for raw Forward PVC coverage while migration is in progress

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
