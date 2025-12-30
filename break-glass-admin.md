# Break-glass local admin

Use the local admin path when LDAP is unavailable or you need to recover access.

## What it is
- Skyforge supports a local admin user list (`SKYFORGE_ADMIN_USERS`) plus a shared password (`SKYFORGE_ADMIN_PASSWORD`).
- In this k3s deployment the password is sourced from the Kubernetes secret `skyforge-admin-shared` (key: `password`).

## Get the password (cluster admin)
```bash
kubectl -n skyforge get secret skyforge-admin-shared -o jsonpath='{.data.password}' | base64 -d; echo
```

## Check who is allowed
```bash
kubectl -n skyforge get configmap skyforge-config -o jsonpath='{.data.SKYFORGE_ADMIN_USERS}'; echo
```

## Rotate
1) Update the secret `skyforge-admin-shared` (key `password`) using your secret manager of choice.
2) Restart the `skyforge-server` deployment so the new secret is picked up:
```bash
kubectl -n skyforge rollout restart deploy/skyforge-server
```

Rotation also impacts other bootstrapped services that reuse the shared admin password (Gitea, NetBox, Nautobot, Semaphore, etc), so prefer rotating only between maintenance windows.
