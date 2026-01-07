# Post-install verification (kubectl only)

This checklist is intended to quickly validate cluster wiring without using the UI, to avoid doing E2E twice.

## Pods ready
```bash
kubectl -n skyforge get pods
```

## Ingress + middleware present
```bash
kubectl -n skyforge get ingressroute,middleware
```

## ConfigMap wiring
```bash
kubectl -n skyforge get configmap skyforge-config -o yaml
```

## Health endpoints (inside cluster)
```bash
kubectl -n skyforge run skyforge-health --rm -i --restart=Never --image=curlimages/curl -- \
  sh -lc 'curl -fsS http://skyforge-server:8085/api/health'
```

## DNS (Technitium) health (optional)
```bash
kubectl -n skyforge get deploy,svc,ingressroute technitium-dns
```

## Quick SSO sanity (no browser)
This validates that the Skyforge server can mint sessions and that protected services are reachable.

```bash
kubectl -n skyforge get secret skyforge-admin-shared
kubectl -n skyforge get deploy skyforge-server
kubectl -n skyforge get deploy gitea netbox nautobot
```

## Yaade sanity (optional)
```bash
kubectl -n skyforge rollout status deploy/yaade
```
