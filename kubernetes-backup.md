# Kubernetes backup / restore (k3s single-node, local-path)

This is a pragmatic backup plan for a **single-node** host running **k3s** with the default `local-path` storage class.

## What to back up

1) **k3s datastore**
- If using default k3s (sqlite): `/var/lib/rancher/k3s/server/db/state.db`
- If using embedded etcd: use k3s etcd snapshot tooling (preferred)

2) **PersistentVolume data** (local-path provisioner)
- Default directory: `/var/lib/rancher/k3s/storage/`

3) **Skyforge runtime secrets and TLS**
- `k8s/overlays/k3s-traefik-secrets/secrets/` (gitignored)
- `./certs/` (gitignored)

## Backup procedure (single node)

1) Scale down workloads to reduce write activity:
```bash
kubectl -n skyforge scale deploy --all --replicas=0
kubectl -n skyforge get pods
```

2) Back up k3s datastore + PVs:
```bash
ts="$(date +%Y%m%d-%H%M%S)"
dest="/root/skyforge-backups/${ts}"
mkdir -p "${dest}"

# k3s sqlite datastore (if present)
if [ -f /var/lib/rancher/k3s/server/db/state.db ]; then
  cp -a /var/lib/rancher/k3s/server/db/state.db "${dest}/k3s-state.db"
fi

# local-path PVs
tar czf "${dest}/k3s-local-path-storage.tgz" -C /var/lib/rancher/k3s storage
```

3) Scale workloads back up:
```bash
kubectl -n skyforge scale deploy --all --replicas=1
kubectl -n skyforge rollout status deploy --all --timeout=600s
curl -k https://<hostname>/status/summary
```

## Restore procedure (single node)

1) Stop k3s:
```bash
sudo systemctl stop k3s || true
sudo systemctl stop k3s-agent || true
```

2) Restore datastore + PVs:
```bash
ts="<timestamp>"
src="/root/skyforge-backups/${ts}"

# local-path PVs
rm -rf /var/lib/rancher/k3s/storage
tar xzf "${src}/k3s-local-path-storage.tgz" -C /var/lib/rancher/k3s

# sqlite datastore (if used)
if [ -f "${src}/k3s-state.db" ]; then
  cp -a "${src}/k3s-state.db" /var/lib/rancher/k3s/server/db/state.db
fi
```

3) Start k3s:
```bash
sudo systemctl start k3s
```

4) Validate:
```bash
kubectl get nodes
kubectl -n skyforge get pods
curl -k https://<hostname>/status/summary
```

## Notes
- This approach is intentionally simple and works best for **single-node** + `local-path`.
- If you move to Longhorn/CSI, prefer volume snapshots and an object-store backup flow.
