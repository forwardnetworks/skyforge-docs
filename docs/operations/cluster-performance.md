# Cluster Performance Runbook

This runbook captures the Skyforge cluster tuning workflow used for production-like performance validation.

## 1) Capture baseline

```bash
cd <skyforge-repo-root>
./scripts/ops/perf/baseline-cluster.sh
SKYFORGE_USERNAME=skyforge SKYFORGE_PASSWORD='<admin-password>' \
  ./scripts/ops/perf/baseline-api-latency.sh
SKYFORGE_USERNAME=skyforge SKYFORGE_PASSWORD='<admin-password>' \
  ./scripts/ops/perf/baseline-queue.sh
```

## 2) Apply worker tuning

```bash
cd <skyforge-repo-root>
./scripts/ops/tune-worker-nodes.sh --mode apply --restart-agents
```

## 3) Apply Cilium performance overlay

```bash
cd <skyforge-repo-root>
PERF_VALUES_FILE=./deploy/cilium-values-performance.yaml \
  ./scripts/ops/reconcile-cilium-gateway.sh
./scripts/ops/perf/check-cilium-health.sh
```

Expected Cilium config after apply:

- `routing-mode=native`
- `datapath-mode=netkit`
- `bpf-map-dynamic-size-ratio=0.01`
- `enable-bandwidth-manager=true`
- `enable-bbr=true`

## 4) Deploy Skyforge cron/cleanup tuning

```bash
cd <skyforge-repo-root>
./scripts/ops/helm-upgrade-safe.sh \
  --namespace skyforge \
  --release skyforge \
  --chart ./components/charts/skyforge \
  -- --reuse-values -f ./components/charts/skyforge/values-prod-skyforge-local.yaml --timeout 20m
```

## 5) Validate placement and queue health

```bash
cd <skyforge-repo-root>
./scripts/ops/audit-control-plane-isolation.sh
./scripts/ops/audit-node-layout.sh
SKYFORGE_USERNAME=skyforge SKYFORGE_PASSWORD='<admin-password>' \
  ./scripts/ops/perf/check-queue-latency.sh
```

## Rollback

```bash
cd <skyforge-repo-root>
./scripts/ops/rollback-worker-tuning.sh
./scripts/ops/rollback-cilium-perf.sh
```

## Node-label caveat (Longhorn)

Longhorn PV `nodeAffinity` is immutable for hostname values in existing volumes.  
If worker node hostnames changed, preserve compatibility by keeping worker node label values aligned with the legacy hostnames expected by bound PVs:

- `skyforge-worker-1 -> kubernetes.io/hostname=skyforge-1`
- `skyforge-worker-2 -> kubernetes.io/hostname=skyforge-2`
- `skyforge-worker-3 -> kubernetes.io/hostname=skyforge-3`

Without this, pods using pre-existing PVCs can remain unschedulable.

To audit/reconcile labels with explicit legacy mapping:

```bash
cd <skyforge-repo-root>
./scripts/ops/reconcile-node-identity.sh --mode audit \
  --map-csv 'skyforge-worker-1=skyforge-1,skyforge-worker-2=skyforge-2,skyforge-worker-3=skyforge-3'
```
