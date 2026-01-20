# Forward Collector (In-Cluster)

Skyforge can run a **per-user Forward collector inside the Skyforge Kubernetes cluster**.

Skyforge creates the collector in Forward (SaaS or on-prem) and stores the returned `authorizationKey`. That authorization key is used as the in-cluster collector `TOKEN`.

## Notes (Key Persistence + Upgrades)

- Forward Enterprise collectors generate and use an encryption key (`customer_key.pb`) which protects locally-stored secrets. If you lose it, you have to re-enter secrets after restarts/upgrades.
- Skyforge **persists** this file by mounting a per-user PVC at `/collector/private` (so `customer_key.pb` survives pod restarts and image upgrades).
- To upgrade: change `skyforge.forwardCollector.image` to a newer tag and redeploy Skyforge, then click **Restart collector** in the UI (or simply wait for the Deployment rollout).
- To rotate credentials: use **Reset collector** (creates a new Forward collector and updates the stored authorization key). The local `customer_key.pb` stays intact.
- To fully remove: use **Clear collector settings** (deletes stored creds and deletes the in-cluster Deployment + PVC).

## Configure In-Cluster Collector (Skyforge)

- Helm values:
  - Set `skyforge.forwardCollector.image` (example Harbor tag below).
  - Optional: set `skyforge.forwardCollector.heapSizeGB` to control memory (maps to `COLLECTOR_HEAP_SIZE`).
  - Optional: set `skyforge.forwardCollector.imagePullSecretName` if your registry requires auth.

Example (Harbor):

```bash
skyforge:
  forwardCollector:
    image: harbor.local.forwardnetworks.com/forward/fwd_collector:26.1.0-05
    pullPolicy: Always
    imagePullSecretName: harbor-pull
    imagePullSecretNamespace: skyforge
    heapSizeGB: 16
```

## User Flow

1) Open **Collector** in the UI.
2) Enter Forward base URL (SaaS or on-prem), credentials, then **Save**.
3) Skyforge creates (or reuses) a per-user Forward collector and deploys the in-cluster collector pod.
4) When connected, the UI will show the pod as `Running` and the collector as present in Forward.
