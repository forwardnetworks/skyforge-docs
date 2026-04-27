# Skyforge Architecture Guidelines

This document is the active architecture checklist for Skyforge.

Use it as the default review standard for new services, APIs, portal work,
charts, and integrations. If a proposal conflicts with this document, the
proposal needs an explicit reason.

## 1. System model

Skyforge is:
- an Encore-based application control plane
- running on Kubernetes as the platform substrate
- using Kubernetes-native primitives for placement, networking, storage,
  exposure, autoscaling, and reconciliation where those concerns belong

Skyforge is not:
- a custom internal framework layered on top of Encore and Kubernetes
- a replacement for the Kubernetes scheduler
- a generic plugin runtime with ad hoc lifecycle rules

## 2. Architectural default

For new work, prefer this order:
1. Encore-native service/API pattern
2. Kubernetes-native primitive or controller pattern
3. direct integration contract to the external system
4. only then consider a custom abstraction

If a design starts with a proxy bridge, compatibility shim, or bespoke runtime
wrapper, assume it is the wrong shape until proven otherwise.

## 3. Domain boundaries

### Encore owns the control plane

Encore services should own:
- typed APIs
- auth and middleware
- policy and quota resolution
- reservation and scheduling admission
- orchestration workflows
- background jobs, queues, and cron
- user and admin UI contracts
- integration configuration and lifecycle orchestration

### Kubernetes owns the substrate

Kubernetes-native components should own:
- pod scheduling
- node placement
- autoscaling
- Services, Gateway API, and networking
- PVCs, storage classes, and backups
- controller-style reconciliation when actual desired-vs-observed convergence is needed

### Rule

Do not reimplement a Kubernetes subsystem inside Encore.
Do not hide ordinary business workflows inside custom controllers unless they
really need reconciliation semantics.

## 4. Service design checklist

Create or extend an Encore service when the work has one clear domain contract.

A service is justified when it owns one of:
- identity and session handling
- platform policy, quotas, reservations, and capacity
- a specific integration domain such as Teams or ServiceNow
- deployment runtime orchestration
- storage or artifact lifecycle
- worker execution and queue processing

Do not create a service because:
- a page exists in the portal
- the code file got large
- one handler needs a helper

Before adding a new service, answer:
- What domain does it own?
- What data does it own?
- What APIs does it expose?
- What services may call it?
- What should stay private/internal?

## 5. API contract checklist

All new APIs should satisfy these rules:
- typed request/response structs
- stable, explicit route shape
- auth/middleware enforced at the boundary
- no inline vendor/client logic in the handler
- no UI-specific response hacks when a proper contract can be defined
- no backwards-compatibility aliases unless there is a real migration requirement

Preferred shape:
- handler delegates to a domain service or focused helper
- focused package owns the heavy logic
- wrapper layer in `components/server/skyforge` stays thin where possible

Avoid:
- giant catch-all API files
- repeating permission logic across handlers
- handler-local orchestration state machines

## 6. Async and workflow checklist

If the operation can take time, fail transiently, or needs auditability:
- enqueue it
- persist lifecycle state
- expose status through typed APIs
- use Encore-native cron/task/worker patterns

Prefer:
- request -> validate -> record intent -> enqueue -> return quickly
- worker -> execute -> persist events -> publish status

Avoid:
- fire-and-forget goroutines for durable work
- hidden side effects after the request has returned
- browser polling as the primary state model when an evented/status model exists

## 7. Integration checklist

Integrations should be adapters, not architecture anchors.

For each integration:
- keep config and secret handling in Skyforge
- keep vendor clients small and typed
- isolate transport/protocol details from the portal contract
- authorize in Skyforge before calling the adapter
- prefer direct Service or Gateway routing over extra proxy layers
- prefer a per-integration service/package over embedding vendor logic into unrelated handlers

Use Kubernetes-native exposure where possible:
- direct Service backends
- Gateway API routing
- native TLS and service discovery

Avoid:
- extra reverse proxies just to paper over routing design
- local-only bridges that create prod drift
- vendor semantics leaking into core platform models

## 8. Controller and reconciliation checklist

Use a controller-style design only when the system must continually converge
actual state toward desired state.

That usually means:
- watching cluster objects
- reacting to drift automatically
- continuously reconciling lifecycle state

Good candidates:
- KubeVirt VM lifecycle automation
- long-lived managed platform components that must recover after node/pod changes

Bad candidates:
- one-shot business workflows
- ordinary API-triggered provisioning
- logic that can be modeled as request + task + status

If you need reconciliation:
- prefer Kubernetes-native controller patterns
- keep the desired state explicit
- keep observed state explicit
- make convergence idempotent

## 9. Portal checklist

The portal is a typed client and operator surface, not a second control plane.

Preferred rules:
- TanStack Query is the state/cache layer for server state
- portal components consume typed API clients
- no inline `fetch` in components
- page state should not duplicate server lifecycle state when a query exists
- admin/operator views should map to real backend contracts, not browser-only heuristics

For new UI groupings, use this taxonomy:
- `Platform`: capacity, reservations, scheduling, worker pools, placement
- `Observability`: Grafana, Prometheus, signals, health, metrics
- `Policy` or `Access`: RBAC, quotas, reset authority, launch permissions
- `Integrations`: external systems and adapters
- `Forward`: Forward-specific workflows and embedded tools

Avoid broad labels like `Governance` for platform operations and observability.

## 10. Naming checklist

Use names that match the real contract.

Preferred vocabulary:
- `platform`
- `observability`
- `policy`
- `access`
- `reservation`
- `placement`
- `integration`
- `reset`
- `baseline`

Avoid umbrella names that blur boundaries:
- `governance` for scheduling/capacity/metrics
- `signals` when the contract is really observability
- `manager`, `engine`, `controller` unless the behavior actually matches the term

## 11. Deployment and runtime checklist

Deployment design should stay prod-shaped across environments.

Required defaults:
- Helm values define the product contract
- environment overlays stay thin and documented
- local dev must not invent a different architecture
- direct native primitives before repair scripts or extra frontdoors

Allowed use of scripts:
- image build/push
- deploy orchestration
- verification and smoke checks
- deterministic bootstrap that cannot live cleanly in a chart or controller

Scripts must not become the architecture.

## 12. Documentation checklist

When architecture changes:
- update the active guideline or runbook in `components/docs/`
- archive or delete outdated design notes
- do not leave multiple active documents describing conflicting architectures

Use these categories:
- active standards in `components/docs/`
- implementation plans in `components/docs/harnesses/exec-plans/active/`
- historical material only under `components/docs/harnesses/archive/legacy/`

## 13. Anti-patterns

Treat these as design smells that require justification:
- compatibility shims kept after the migration is complete
- local-only proxies or route bridges
- hidden fallback logic that changes semantics between environments
- giant service or API files that own unrelated domains
- browser-side recomputation of backend policy decisions
- custom scheduler behavior that should be admission plus Kubernetes scheduling
- a second internal framework layered over Encore and Kubernetes

## 14. Review gate

Before merging architecture-affecting work, verify:
- Does the change strengthen an existing domain boundary instead of blur it?
- Is Encore being used for application control-plane concerns?
- Is Kubernetes being used for substrate concerns?
- Did we avoid introducing a custom framework or proxy layer?
- Did we remove or archive stale docs that would now mislead maintainers?
- Did we keep the contract OSS-friendly and environment-consistent?

If the answer to any of those is no, the design needs another pass.
