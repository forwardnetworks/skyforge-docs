# Forward Collector (In-Cluster)

Skyforge can run a **per-user Forward collector inside the Skyforge Kubernetes cluster**.

Skyforge creates the collector in Forward (SaaS or on-prem) and stores the returned `authorizationKey`. That authorization key is used as the in-cluster collector `TOKEN`.

## Notes (Key Persistence + Upgrades)

- Forward Enterprise collectors generate and use an encryption key (`customer_key.pb`) which protects locally-stored secrets. If you lose it, you have to re-enter secrets after restarts/upgrades.
- Skyforge **persists** this file by mounting a per-user PVC at `/collector/private` (so `customer_key.pb` survives pod restarts and image upgrades).
- To upgrade manually in-place: click **Check updates** then **Upgrade** (or **Upgrade all**) on the Collector page.
- Upgrade uses registry digest checks and patches the collector Deployment to the newest digest for the configured image tag.
- To fully remove: delete the collector entry in the Collector page (removes saved credentials and the in-cluster Deployment + PVC).

## Configure In-Cluster Collector (Skyforge)

- Helm values:
  - Set `skyforge.forwardCollector.image` (example GHCR tag below).
  - Optional: set `skyforge.forwardCollector.heapSizeGB` to control memory (maps to `COLLECTOR_HEAP_SIZE`).
  - Optional: set `skyforge.forwardCollector.imagePullSecretName` if your registry requires auth.

Example (GHCR):

```bash
skyforge:
  forwardCollector:
    image: harbor.local.forwardnetworks.com/forward/fwd_collector:26.3.0-09
    pullPolicy: Always
    imagePullSecretName: ghcr-pull
    imagePullSecretNamespace: skyforge
    heapSizeGB: 16
```

## User Flow

1) Open **Collector** in the UI.
2) Enter Forward base URL (SaaS or on-prem), credentials, then **Create**.
3) Skyforge creates (or reuses) a per-user Forward collector and deploys the in-cluster collector pod.
4) Use **Check updates** and **Upgrade** to pull newer collector builds without redeploying Skyforge.
5) When connected, the UI will show the pod as `Running` and the collector as present in Forward.
