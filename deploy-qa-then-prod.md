# Deploying Skyforge (QA → Prod)

Skyforge is deployed with Helm from `charts/skyforge`.

Policy: always deploy to QA first, validate, then deploy to prod.

## Prereqs

- VPN connected (Cato).
- SSH access to the cluster nodes.
- `kubectl` + `helm` installed locally.
- Set `KUBECONFIG` to the environment you intend to deploy to.

## Deploy to QA

QA has environment-specific secrets that must not be committed:

- `deploy/skyforge-secrets-qa.yaml` (gitignored)
- `skyforge-private/.kubeconfig-skyforge-qa` (gitignored)

1) Create a local SSH tunnel to QA’s k3s API:

```bash
ssh -fN -L 6443:127.0.0.1:6443 ubuntu@skyforge-qa.local.forwardnetworks.com
```

2) Fetch kubeconfig from QA:

```bash
ssh ubuntu@skyforge-qa.local.forwardnetworks.com 'sudo cat /etc/rancher/k3s/k3s.yaml' > skyforge-private/.kubeconfig-skyforge-qa
chmod 600 skyforge-private/.kubeconfig-skyforge-qa
export KUBECONFIG=$PWD/skyforge-private/.kubeconfig-skyforge-qa
```

3) Deploy:

```bash
cd skyforge-private
helm upgrade --install skyforge charts/skyforge -n skyforge --create-namespace \
  -f deploy/skyforge-values.yaml \
  -f deploy/skyforge-values-qa.yaml \
  -f deploy/skyforge-secrets.yaml \
  -f deploy/skyforge-secrets-qa.yaml \
  --wait --timeout 20m
```

4) Validate:

```bash
kubectl -n skyforge get pods
curl -k https://skyforge-qa.local.forwardnetworks.com/healthz
curl -k https://skyforge-qa.local.forwardnetworks.com/status
```

If a Helm deploy is stuck waiting, check for a failed `netbox-admin-bootstrap` job and rerun it:

```bash
kubectl -n skyforge delete job netbox-admin-bootstrap --ignore-not-found
kubectl -n skyforge apply -f charts/skyforge/files/kompose/netbox-admin-bootstrap-job.yaml
kubectl -n skyforge wait --for=condition=complete job/netbox-admin-bootstrap --timeout=10m
```

## Deploy to prod

1) Create a local SSH tunnel to prod’s VIP k3s API:

```bash
ssh -fN -L 6443:127.0.0.1:6443 ubuntu@skyforge-1.local.forwardnetworks.com
```

2) Fetch kubeconfig from prod:

```bash
ssh ubuntu@skyforge-1.local.forwardnetworks.com 'sudo cat /etc/rancher/k3s/k3s.yaml' > skyforge-private/.kubeconfig-skyforge
chmod 600 skyforge-private/.kubeconfig-skyforge
export KUBECONFIG=$PWD/skyforge-private/.kubeconfig-skyforge
```

3) Deploy:

```bash
cd skyforge-private
helm upgrade --install skyforge charts/skyforge -n skyforge --create-namespace \
  -f deploy/skyforge-values.yaml \
  -f deploy/skyforge-secrets.yaml \
  --wait --timeout 20m
```

4) Validate:

```bash
kubectl -n skyforge get pods
curl -k https://skyforge.local.forwardnetworks.com/healthz
curl -k https://skyforge.local.forwardnetworks.com/status
```
