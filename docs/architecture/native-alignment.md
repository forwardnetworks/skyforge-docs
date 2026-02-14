# Native Alignment Contract

This document defines what "native" means for Skyforge.

## Encore-native

- Backend behavior is implemented in Encore services/tasks.
- Runtime configuration is supplied via chart-managed secrets/config maps.
- No hidden out-of-band runtime dependencies.

## TanStack-native

- Frontend routes are file-based via `createFileRoute`.
- `routeTree.gen.ts` is generated output (not manually edited).
- Query/data loading uses TanStack Query patterns.

## Cilium-native

- Public ingress uses Gateway API (`gatewayClassName: cilium`).
- Any Envoy proxy is an explicit compatibility layer behind Gateway.
- Auth/session behavior must remain consistent with Skyforge auth boundaries.

## Allowed pragmatic glue

Pragmatic compatibility layers are allowed when required for product behavior, but must be:

- explicitly documented,
- covered by regression tests,
- tracked for eventual reduction.
