# Clabernetes Upstreaming Plan (From Skyforge Fork)

This document defines how to upstream the fork changes in `vendor/clabernetes` with the highest
chance of acceptance while preserving current working container deployments (`eos`, `iol`,
`ios-xrd`).

## Current divergence snapshot

- Fork branch is significantly ahead of upstream (`upstream/main`) and includes broad runtime
  changes plus generated artifacts.
- Container deployments are validated in our environment (`eos`, `iol`, `ios-xrd`).
- VM/KubeVirt path exists but is not yet validated end-to-end at the same confidence level.

## Upstreaming strategy

Use a **slice-by-slice PR stack**. Do not submit the full fork delta as a single PR.

## PR Slice 1: Low-risk correctness and determinism

Scope:
- deterministic node ordering and render behavior
- exec parser quoting improvements + tests
- connectivity watcher edge-case fixes that are runtime-agnostic

Acceptance bar:
- existing upstream test suites pass
- no API/CRD schema changes
- no runtime mode behavior changes

## PR Slice 2: Container bootstrap parity fixes (k8s runtime)

Scope:
- cEOS startup-config/env bootstrap parity
- IOL startup/bootstrap handling in k8s runtime
- XR bootstrap script/configmap hardening needed for service-path reachability

Acceptance bar:
- unit/integration tests for controller render paths updated
- no downstream-specific naming, credentials, or registry assumptions

## PR Slice 3: Runtime classification + VM reconciliation (optional feature)

Scope:
- introduce runtime class resolution (`container` vs `vm`)
- add VM reconciler resources and readiness/status handling
- keep existing container path unchanged

Guardrails:
- feature must be additive and explicitly scoped
- avoid hard-cut semantics that remove existing upstream workflows

## Keep Fork-Only (for now)

These changes should remain fork-local until upstream requests/accepts the direction:

- hard cut to k8s-only runtime backend
- removal of docker/containerlab launcher runtime surfaces
- Skyforge-specific operational assumptions

## Hygiene requirements before each PR

- remove downstream registry/org examples from runtime paths and tests
- keep generated files minimized to only those required by schema/API changes
- include explicit migration notes when schema/CRD fields change

## Validation gates

For every PR slice:

1. `go test ./controllers/topology -count=1`
2. `go test $(go list ./... | rg -v '/e2e/') -count=1`
3. targeted runtime checks for affected scope (container-only for slices 1-2)

## Recommended execution order

1. Upstream PR Slice 1
2. Upstream PR Slice 2
3. Re-evaluate VM scope and decide if Slice 3 is submitted upstream or kept fork-local
