# Architecture Boundaries

This is the agent-facing routing doc for design constraints. The full standards
remain in [../architecture-guidelines.md](../architecture-guidelines.md).

## Default order

1. Encore-native service/API pattern.
2. Kubernetes-native primitive or controller pattern.
3. Direct integration contract to the external system.
4. Custom abstraction only with an explicit removal path or durable reason.

## Domain ownership

- Encore owns typed APIs, auth, policy, orchestration workflows, queues, cron,
  and user/admin UI contracts.
- Kubernetes owns scheduling, placement, Services, Gateway API, PVCs, storage,
  backups, autoscaling, and substrate reconciliation.
- Portal is a typed operator surface, not a second control plane.

## Netlab + KNE hard boundary

Do not add runtime topology rewrites for `netlab+kne` flows. Use netlab's native
provider/plugin conversion path and defaults/templates. The only allowed runtime
exception is the user-driven `NETLAB_DEVICE` override.

## Integration boundary

Vendor clients should be small and typed. Authorize in Skyforge before calling
adapters. Do not introduce proxy bridges or local-only routing if Kubernetes or
Gateway API can express the contract directly.
