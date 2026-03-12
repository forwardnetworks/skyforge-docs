# Skyforge Capacity, Policy, and Platform Scale Plan

## Summary

This plan turns Skyforge from a capable internal orchestration platform into a
policy-driven, schedulable, and budgetable GTM platform.

The immediate business drivers are:

- make Skyforge usable as `Demo Foundry 2.0`
- support repeatable, curated demos with tenant isolation
- support sandbox and persistent lab workflows without cross-user interference
- support full Forward tenant reset workflows so demos and sandboxes can be
  rebuilt from a known-good baseline
- provide a credible cost and capacity model for GTM rollout
- enable eventual hybrid infrastructure placement across cloud and reclaimed
  on-prem compute

This plan is intentionally phased. We should not start with hybrid cluster
engineering. We need the policy and scheduling primitives first, otherwise
capacity planning will be guesswork.

## Goals

- define a first-class role and capability model for GTM-scale access
- define a first-class resource and template sizing model
- implement explicit reservation and scheduling flows
- define a first-class tenant reset and reprovision workflow for Forward-backed
  labs
- surface capacity, queue, and cost observability in the product
- prepare Skyforge for hybrid cloud/on-prem worker placement using the same
  cluster model

## Non-Goals

- fully solve every infrastructure topology in phase 1
- replace the Kubernetes scheduler with custom placement logic
- build calendar integrations before reservation semantics exist
- implement fine-grained cost accounting before resource classes exist

## Current State

### Implemented

- per-user isolation / tenant-scoped workflows
- Git-backed templates and curated quick deploy catalog
- task queue, task priorities, worker activation/reconciliation, and lease state
- Hetzner deployment path with cluster autoscaler and KEDA support
- platform policy foundation:
  - role profiles, capabilities, quota overrides, reservation records, and
    Forward tenant reset runs are first-class persisted contracts
  - effective user policy resolution exists as a dedicated Encore-native
    platform service
- admin/user RBAC foundation:
  - direct roles: `USER`, `ADMIN`
  - explicit per-user API allow/deny overrides

### Missing

- no first-class persona/capability RBAC model
- no template or catalog-level authorization model
- no quota model by user/role/template class
- no reservation scheduler for future time windows
- no resource class model for templates
- no capacity planner tied to actual GTM workflows
- no explicit hybrid placement model for cloud vs on-prem pools
- no first-class tenant reset lifecycle for Forward org rebuilds

## Phase 0: Data Model and Product Contract

### Objective

Introduce the product-level concepts we need before deeper implementation.

### Deliverables

- [x] Define **persona roles**:
  - `viewer`
  - `demo-user`
  - `sandbox-user`
  - `trainer`
  - `integration-user`
  - `admin`
- [x] Define **capabilities**:
  - view curated catalog
  - launch curated templates
  - launch custom templates
  - persist lab state
  - reserve future capacity
  - manage integrations
  - impersonate users
  - manage users/roles
  - override reservations
- [x] Define **template resource classes**:
  - `small`
  - `standard`
  - `heavy`
  - `demo-foundry`
- [x] Define **reservation types**:
  - immediate interactive launch
  - scheduled future reservation
  - persistent sandbox lease
  - admin reserved block
- [x] Define **tenant reset modes**:
  - soft reset: reset Skyforge-managed deployment state only
  - hard reset: disable/delete/recreate Forward tenant objects from scratch
  - curated reset: rebuild to a known baseline and reprovision managed
    dependencies
- [x] Define **pool classes**:
  - `control`
  - `app`
  - `lab`
  - `burst`
  - `onprem-lab` (future/hybrid)

### Done Criteria

- all above concepts documented in code-facing types and docs
- no new scheduling or RBAC code merges without using these contracts

## Phase 1: RBAC Hardening for Broad GTM Use

### Objective

Move from `user/admin + API overrides` to a scalable authorization model.

### Deliverables

- [x] Add a **role profile** layer above direct user grants
- [x] Map role profiles to capability bundles
- [x] Keep direct API permission overrides as exception-only controls
- [x] Add **template visibility** policy:
  - which users can see which templates
  - which templates are curated-only
- [x] Add **template launch** policy:
  - which users can launch which resource classes
- [x] Add **persistence** policy:
  - who can create persistent labs
  - max duration by role/profile
- [x] Add **reset** policy:
  - who can reset their own tenant
  - who can hard reset curated/demo tenants
  - who can rebuild shared baselines
- [x] Add **quota** policy:
  - max concurrent labs
  - max resource class
  - max persistent labs
- [x] Add admin UI for:
  - role profile assignment
  - capability overview
  - quota display/edit

### Suggested Implementation Order

1. add profile and capability types in server
2. add persistence tables / migrations
3. add resolution logic in auth middleware / policy helpers
4. update admin settings UI
5. migrate existing users to default profiles

### Done Criteria

- RBAC no longer depends on raw endpoint overrides as the main control surface
- template and persistence access can be governed without bespoke exceptions
- tenant reset authority is governed by role/capability, not ad hoc admin action

## Phase 2: Template Resource Classification

### Objective

Make deployments schedulable and costable by introducing resource intent.

### Deliverables

- [x] Extend template metadata with:
  - `resourceClass`
  - estimated vCPU
  - estimated memory
  - estimated storage
  - integration dependencies
  - placement hints
  - reset baseline mode
- [x] Add a catalog/build-time validator that requires these fields for curated
  templates
- [x] Add a fallback estimator for custom uploads / custom templates
- [x] Surface resource class and estimate in portal deploy/quick deploy flows
- [x] Record actual post-deploy resource usage for comparison against estimates

### Progress

- [x] Curated quick deploy templates now carry explicit `resourceClass`.
- [x] Curated quick deploy templates now carry explicit `resetBaselineMode`,
  `integrationDependencies`, and `placementHints`.
- [x] Quick deploy launches persist that intent metadata into deployment config
  so later reset/scheduling paths can consume recorded intent instead of
  heuristics.
- [x] Resource-estimate contracts now include deterministic storage estimates
  and deployment intent persistence records estimated storage alongside CPU and
  memory for both curated quick deploy and custom netlab creation/update paths.
- [x] Admin quick-deploy catalog updates now validate curated template metadata
  and confirm that each referenced blueprint still produces a supported netlab
  resource estimate before the catalog is accepted.
- [x] Custom and user-supplied netlab deployments now infer and persist a
  fallback `resourceClass` plus estimated CPU and memory intent when the caller
  did not declare one explicitly.
- [x] Actual post-deploy resource usage is now recorded in a dedicated
  deployment-usage snapshot table via worker cron refresh instead of being
  derived only transiently at overview read time.

### Done Criteria

- every curated template has a declared resource class
- the platform can show estimated resource demand before launch

## Phase 2.5: Forward Tenant Reset and Reprovision

### Objective

Make Forward-backed demo and sandbox tenants safely rebuildable from a
known-good baseline.

### Deliverables

- [x] Define a tenant reset state machine:
  - requested
  - draining
  - deleting
  - reprovisioning
  - validating
  - ready
  - failed
- [x] Add a reset API contract for Forward-backed tenants:
  - reset current user tenant
  - admin reset another tenant
  - rebuild curated demo tenant from baseline
- [x] Reset workflow must cover:
  - Forward org disable/delete/recreate where appropriate
  - Forward user recreate
  - API key regeneration
  - in-cluster collector redeploy/rebind
  - Skyforge-managed tenant credential reset
  - baseline demo metadata capture and re-apply from an explicit reset-run contract
- [x] Add UI:
  - user-visible reset for their own sandbox where allowed
  - admin-visible hard reset for curated/demo tenants
  - progress and audit trail
- [x] Add safety controls:
  - [x] confirmation and blast-radius messaging
  - [x] role/capability gating
  - [x] cooldown / rate-limit
  - [x] async execution with resumable status
- [x] Add validation:
  - [x] Forward org exists and is healthy
  - [x] tenant user exists
  - [x] API key present
  - [x] collector connected
  - [x] tenant baseline assets restored

### Important Notes

- This should be implemented as an explicit lifecycle workflow, not as a loose
  collection of secret deletes and reprovision calls.
- Reset must be async and observable because collector and Forward-side
  provisioning are not instantaneous.
- Curated demo reset and user sandbox reset should use the same core state
  machine with different policy gates.

### Progress

- [x] Reset runs are now first-class platform records with typed baseline
  metadata captured at request time.
- [x] Worker orchestration now replays managed baseline deployments from the
  persisted reset-run baseline instead of reconstructing them only from live
  runtime state during reprovision.
- [x] User self-service reset UI exists for managed Forward tenants.
- [x] Admin reset UI now exists for selected users with mode selection and
  reset-run history in Settings > Users.
- [x] Platform reset requests now enforce a per-user cooldown window in
  addition to the existing single-active-run guard.
- [x] Reset validation now confirms the reprovisioned Forward credentials were
  rotated after the reset request and fails if managed baseline deployments were
  not fully rebound to the recreated managed collector.
- [x] Reset validation now also requires every managed baseline deployment to
  queue a fresh post-reset Forward sync before the run can finish `ready`.
- [x] Reset validation now verifies each restored managed-baseline deployment
  has a fresh `forward-sync` task created after the reset request and that the
  task is not already in a terminal failure state.
- [x] Reset validation now waits inside a bounded validation window for each
  restored managed-baseline deployment to leave `queued` and enter a live
  `forward-sync` state (`running`/`success`) before the run can finish `ready`.
- [x] Self-service and admin reset flows now require explicit destructive
  confirmation in the portal before queuing hard or curated rebuilds.

### Done Criteria

- an admin can hard reset a curated/demo tenant to a known-good baseline
- an authorized user can reset their own sandbox tenant when policy allows
- reset state and validation are visible in the UI and audit trail

## Phase 3: Reservation Scheduler

### Objective

Support predictable demo reservations and fair allocation instead of pure
best-effort queuing.

### Deliverables

- [x] Add a `reservations` data model:
  - owner
  - template or resource class
  - requested start/end
  - [x] priority tier
  - status
  - [x] admin override flag
- [x] Add availability checking service
- [x] Add admission logic:
  - reject impossible reservations
  - [x] queue or defer best-effort launches when reserved capacity is protected
- [x] Add scheduling policies:
  - first-come-first-serve baseline
  - [x] admin override
  - [x] reserved capacity for curated demos
  - role-based max concurrency
- [x] Add portal UX:
  - [x] reserve now
  - [x] reserve later
  - [x] view my reservations
  - [x] admin reserved-capacity controls / queue board
- [x] Add API and event model for reservation lifecycle

### Important Notes

- this should build on existing task queue and lease mechanics, not replace them
- reservation is a product-level contract; Kubernetes remains the execution
  scheduler underneath

### Done Criteria

- engineers can reserve resources in advance
- admins can see conflicts and override when needed
- immediate launches respect reservation policy

## Phase 4: Capacity and Cost Reporting

### Objective

Give leadership real numbers for rollout and budget decisions.

### Deliverables

- [x] Add capacity inventory by pool:
  - allocatable CPU/RAM/storage
  - reserved
  - active
  - queued demand
- [x] Add demand reporting by class:
  - queued labs
  - running labs
  - reservations
  - persistent labs
- [x] Add initial availability observability by class:
  - estimated capacity units
  - approved/requested reservations
  - reserved blocks
  - immediate availability
- [x] Add estimate vs actual reporting:
  - template estimate
  - actual runtime usage
  - drift
- [x] Add cost model inputs by pool
- [x] Add dashboards for:
  - GTM admin / leadership
  - platform ops
  - user-facing availability / quota

### Progress

- [x] Admin platform overview now reports Kubernetes-backed capacity inventory
  by pool, including allocatable, requested, and available CPU/memory.
- [x] Admin platform overview now reports demand by resource class using
  deployment, task, and reservation state already persisted in Skyforge.
- [x] Admin platform overview now reports initial availability-by-class observability
  derived from live cluster capacity and reservation pressure.
- [x] Portal admin capacity view renders the new pool inventory, demand, and
  availability sections without depending on brittle field shapes.
- [x] Admin platform overview now reports class-level estimate-versus-actual
  drift using declared resource class estimates and measured Kubernetes request
  footprints for active c9s deployments.
- [x] Admin platform overview now reports pool cost inputs, including provider,
  instance mix, labeled monthly node cost, and baseline monthly cost rollup.
- [x] `/dashboard` is now a real landing surface instead of a redirect and
  renders user-facing quota, reservation, and availability observability from the
  platform model.
- [x] Admin users now see GTM/platform summary cards on `/dashboard` using the
  same live overview contract that powers the deeper capacity page.
- [x] Admin capacity view now highlights blended infra counts for cloud vs on-prem hosts.
- [x] Dashboard and reservations pages surface reservation guidance derived from the new availability contract.
- [x] Admin platform overview now reports per-class marginal monthly cost for
  both cloud burst capacity and blended total capacity.

### Output We Need

- baseline monthly platform cost
- incremental cost per concurrent `standard` lab
- incremental cost per concurrent `heavy` lab
- cloud-only vs blended infra comparison

### Done Criteria

- we can answer budget questions with platform data, not rough guesses

### Status

Phase 4 is now materially complete:

- baseline monthly cost is reported
- per-class marginal cost is reported
- cloud versus blended infra posture is reported
- user-facing quota, reservation, and availability guidance is in-product

## Phase 5: Hybrid Cloud / On-Prem Placement

### Objective

Support a single cluster model with cloud-hosted control/app components and
optional on-prem worker capacity.

### Deliverables

- [x] Define hybrid node onboarding model:
  - network connectivity requirements
  - labels / taints
  - VPN / routing assumptions
- [x] Define workload placement rules:
  - control-plane and portal/server stay cloud-side
  - lab workloads prefer lab/on-prem pools
  - burst workloads go to autoscaled pools
- [x] Add chart defaults for explicit placement by component
- [x] Add runtime visibility for placement decisions
- [x] Add degraded-mode behavior when on-prem workers are unavailable
- [x] Add documentation for reclaiming Lab++ or colo worker nodes into Skyforge

### Constraints

- use standard Kubernetes placement primitives first
- avoid custom schedulers unless proven necessary
- hybrid rollout depends on phase 2 and phase 4 so placement has cost meaning

### Done Criteria

- hybrid pool placement is explicit, observable, and supportable
- cloud/on-prem split is an implementation detail, not tribal knowledge

### Progress

- [x] Platform inventory now classifies node pools into explicit pool classes
  (`control`, `app`, `lab`, `burst`, `onprem-lab`) instead of exposing only raw
  pool names.
- [x] Core Skyforge Helm workloads now expose explicit placement intent using
  native Kubernetes primitives with safe defaults:
  - server prefers `app`
  - worker prefers `app`
  - optional hard requirement is available through `requiredPoolClass`
- [x] Admin capacity view now shows pool class alongside raw pool identity so
  placement intent is visible in the product.
- [x] Deployment detail now exposes runtime placement summaries for c9s labs,
  including preferred pool classes, live actual placement, candidate nodes, and
  degraded placement status.
- [x] Platform overview and user availability now emit typed hybrid-placement
  warnings when `onprem-lab` or other lab capacity disappears, instead of
  leaving degraded placement as tribal knowledge.
- [x] Dashboard, reservations, and platform capacity pages now surface those
  warnings and current cloud/on-prem mode so launch decisions stay visible in
  the product.
- [x] Added `components/docs/hybrid-worker-onboarding.md` as the explicit
  operator procedure for reclaiming Lab++ or other colo worker nodes into the
  Skyforge cluster.

## Phase 6: Enablement and Operating Modes

### Objective

Make Skyforge usable for GTM without forcing every user into sandbox complexity.

### Deliverables

- [x] Define operating modes:
  - [x] curated demo mode
  - [x] sandbox mode
  - [x] persistent integration mode
  - [x] training mode
- [x] Build curated front-end flows where needed:
  - [x] one-click demo launchers
  - [x] training-only surfaces
  - [x] admin-only advanced tooling
- [x] Define standard template catalog ownership
- [ ] Define onboarding and certification workflows

### Done Criteria

- new GTM users can use Skyforge without needing platform-level knowledge

### Progress

- [x] Platform policy and availability contracts now expose explicit
  `operatingModes` plus `primaryOperatingMode` instead of leaving GTM workflow
  modes implicit in profile names and quota numbers.
- [x] Dashboard now surfaces the resolved operating mode and mode-specific
  guidance for curated demo, sandbox, training, integration, and admin-advanced
  users.
- [x] User and admin platform policy cards now show resolved operating modes
  alongside profiles and capabilities.
- [x] Curated quick deploy templates now declare catalog ownership and intended
  operating modes instead of leaving curated template stewardship implicit.
- [x] Quick Deploy now acts as a mode-aware curated launchpad with:
  - recommended templates for the current operating mode
  - explicit launch-mode filtering
  - training-oriented reservation guidance
  - richer curated template metadata visible in the launcher UI
- [x] Dashboard actions now link users directly into the curated quick-deploy
  flow for their current operating mode instead of sending every user to the
  same generic launcher list.

## Recommended Execution Order

1. Phase 0: data model and contract
2. Phase 1: RBAC hardening
3. Phase 2: template resource classification
4. Phase 2.5: Forward tenant reset and reprovision
5. Phase 3: reservation scheduler
6. Phase 4: capacity and cost reporting
7. Phase 5: hybrid cloud/on-prem placement
8. Phase 6: enablement modes and training

## Immediate Next Tranche

This is the first implementation slice we should actually start:

- [x] Add role profiles and capability model
- [x] Add quota model by role profile
- [x] Add template resource class metadata for curated templates
- [x] Add Forward tenant reset schema and state machine stubs
- [x] Add reservation schema and API stubs
- [x] Add an admin-only capacity/reservation overview page

### Current Backend Status

- [x] Added authoritative platform service contracts for:
  - role profiles
  - capabilities
  - resource classes
  - reservation types/status
  - Forward tenant reset modes/status
- [x] Added persistence-backed platform policy resolution:
  - user profile assignments
  - quota overrides
  - effective capability/quota resolution
- [x] Added typed Encore APIs for:
  - policy read/update
  - reservation create/list
  - Forward tenant reset request/list
- [x] Added curated quick deploy resource-class metadata and validation
- [x] Added quick deploy catalog validation against live blueprint estimates
- [x] Added fallback resource-class inference for non-curated netlab templates
- [x] Added persistent deployment usage snapshots for estimate-vs-actual
  reporting
- [x] Added quota-aware launch admission for curated quick deploys
- [x] Added reservation admission rules for overlapping future reservations and
  persistent lab quotas
- [x] Extended reservation records with typed priority tiers and explicit admin
  override state
- [x] Added protected curated-demo capacity using admin reserved-block
  reservations that standard reservations cannot consume
- [x] Added admin-side creation of protected curated-demo reservation windows
  from the platform capacity view
- [x] Added admin platform overview APIs and a first admin capacity/reservations
  page in the portal
- [x] Added queued Forward tenant reset execution with persisted status
  transitions and validation
- [x] Expanded tenant reset local cleanup to clear per-scope Forward
  credentials, deployment-scoped Forward runtime state, and best-effort
  deployment network bindings before reprovision
- [x] Expanded capability enforcement onto custom deployment creation and
  integration-management mutation paths
- [x] Added reservation approval/reject/cancel workflow with admin override
  actions and owner cancel support
- [x] Added first tenant-reset portal UX on the Forward credentials page for
  queued soft/hard rebuilds and recent run visibility
- [x] Added first self-service reservation portal UX for requesting, viewing,
  and cancelling current-user reservations
- [x] Added a first-class reservation preflight API and portal pre-submit
  admission view so users can see the exact scheduler decision before creating
  a reservation
- [x] Added typed reservation lifecycle events plus lifecycle APIs for current
  user and admin reservation detail views, keeping reservation status semantics
  out of ad hoc portal-only logic
- [x] Added reservation priority visibility in user/admin portal surfaces and
  summary reporting for reservations by priority and reserved blocks by class
- [x] Moved deployment lifetime policy, quick deploy lease bounds, and lease
  update enforcement onto platform policy instead of raw admin branching
- [x] Moved admin user, role, and API-permission policy mutations behind
  the manage-users capability in addition to admin route tags
- [x] Moved cross-user notification actions behind platform capability checks
  instead of raw admin exceptions
- [x] Added an explicit `manage_platform_operations` capability and moved task
  reconciliation, observability, quick deploy curation, workspace cleanup,
  smoke-run recording, and admin effective-config surfaces onto it
- [x] Replaced the last behavioral `user.IsAdmin` observability scope split
  with platform capability resolution
- [x] Completed the raw-admin server sweep for auth-tagged operational surfaces;
  the remaining work is no longer mechanical gate migration; it is limited to
  future UX refinements and any deeper platform orchestration we choose to add
- [x] Added auth-aware Skyforge wrapper APIs and audit events
- [x] Added first portal policy editing surfaces:
  - current-user effective platform policy card in My Settings
  - admin per-user profile and quota editor in Settings > Users
- [x] Add richer policy editing flows in the portal:
  - [x] capability visibility derived from selected profiles
  - [x] stronger policy search/filtering and validation UX
  - [x] template/catalog authorization controls for curated quick deploy
- [x] Expand tenant reset from stronger local/runtime cleanup into full curated
  baseline recreation:
  - [x] baseline metadata re-apply
  - [x] curated demo asset recreation for managed baseline deployments by
    rebinding them to the recreated collector and requeueing Forward sync
  - [x] broader validation beyond tenant credential + managed collector presence
  - [x] require fresh post-reset Forward sync enqueue for every restored
    managed baseline deployment

## Risks

- building hybrid infra before scheduling and cost visibility
- keeping RBAC endpoint-centric instead of capability-centric
- allowing custom templates without resource classification
- treating Forward tenant reset as a manual runbook instead of a platform
  workflow
- mixing training, curated demo, and sandbox use cases into one policy model

## Decision Gates

### Gate A: RBAC Readiness

Do not expand Skyforge broadly to GTM until:

- role profiles exist
- template visibility/launch controls exist
- quotas exist

### Gate B: Scheduling Readiness

Do not promise reserved demo capacity until:

- reservation model exists
- availability checks exist
- admin override exists

### Gate B2: Reset Readiness

Do not treat curated demos as disposable/rebuildable platform assets until:

- reset state machine exists
- reprovision validation exists
- reset authority is governed by capability
- reset is observable in UI and audit

### Gate C: Hybrid Readiness

Do not commit to hybrid pool placement until:

- workload placement rules are explicit
- reporting can show pool consumption
- network assumptions are documented and tested

## Notes

- Existing worker queue, priority, lease, and autoscaling mechanisms should be
  reused where possible.
- This plan is intentionally product-first. It focuses on the platform
  contracts leadership actually needs: policy, repeatability, capacity, and
  cost.
