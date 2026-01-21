# Skyforge Packaging TODO (OSS / Repeatable Installs)

This document tracks the work needed to make Skyforge deployments **boring, repeatable, and configurable**, with an eye toward future OSS packaging.

## Goals

- **One-command (or close) install** into a fresh cluster.
- **Predictable “minimal” profile** that always comes up.
- **Optional components are truly optional** (and can be toggled on/off without breaking core).
- **No hidden external dependencies** (DockerHub rate limits, implicit secrets, implicit registries).
- **QA-first rollout discipline** (deploy to QA, then promote to prod).

## Guardrails (Must-Haves)

### 1) Installation Profiles

- [ ] Add `deploy/values-minimal.yaml` (core Skyforge only; disables optional tools by default).
- [ ] Add `deploy/values-full.yaml` (enables everything we ship).
- [ ] Ensure both profiles pass `helm template` + `helm lint`.

### 2) Feature Flags / Component Toggles

We should be able to enable/disable features cleanly at chart install time.

- [ ] Consolidate flags under a single chart subtree, e.g.:
  - `skyforge.features.*` (logical features)
  - `skyforge.components.*` (physical components)
- [ ] Ensure **core RBAC and core resources** are unconditional (only CRD-specific RBAC is gated).
- [ ] Ensure disabling a component:
  - removes its Deployments/Services/Ingresses/Jobs/CRDs cleanly
  - removes it from health checks and UI links
  - does not break server startup

**Example toggle list (to review and finalize):**
- [ ] `components.netbox.enabled`
- [ ] `components.nautobot.enabled`
- [ ] `components.yaade.enabled`
- [ ] `components.coder.enabled`
- [ ] `components.minio.enabled` (or replace with external S3 settings)
- [ ] `components.nsq.enabled` / `components.redis.enabled` (if ever externalized)
- [ ] `features.forwardCollector.enabled`
- [ ] `features.syslogInbox.enabled`
- [ ] `features.snmpTrapInbox.enabled`
- [ ] `features.webhookInbox.enabled`

### 3) Image Strategy (No DockerHub reliance)

- [ ] Maintain an explicit image matrix in chart values, pinned by tag/digest.
- [ ] Prefer GHCR (or another reliable registry) for *all* images.
- [ ] Add a `docs/packaging/images.md` with:
  - required images
  - how to mirror/build them
  - how to override registry/repo prefix

### 4) Secrets & Config Validation

- [ ] Add a “preflight” checklist in docs (what secrets/values are required for each profile).
- [ ] Add runtime validation for required settings:
  - fail fast with a clear error message
  - do not cascade into unrelated failures

### 5) Deploy Script + Safety Checks

- [ ] Add `scripts/deploy.sh` that:
  - verifies correct `KUBECONFIG`/context
  - verifies required secrets exist
  - runs `helm upgrade --install` with `--atomic --wait`
  - runs smoke checks (`server/cmd/smokecheck`) after the rollout
- [ ] Add `scripts/preflight.sh` (optional) to validate prerequisites without deploying.

### 6) CI Gates (Catch breakage before cluster)

- [ ] Add CI job(s) to run:
  - `helm lint charts/skyforge`
  - `helm template` (both minimal + full) and ensure it renders
  - optional: `kubectl apply --dry-run=server` on rendered output

## QA Redeploy Drill (Practice “fresh install”)

- [ ] Define QA process:
  - deploy to QA first
  - promote the same chart revision + image tags to prod
- [ ] Add a periodic “wipe + reinstall” drill checklist:
  - uninstall Helm release
  - delete namespace (or create a new test namespace)
  - reinstall using `values-minimal.yaml`
  - run smoke check
- [ ] Record expected timings and failure modes.

## Notes / Recent Lessons

- DockerHub pulls can break installs (rate limits) → mirror images.
- Conditional RBAC for cluster-scoped resources is a footgun → core RBAC must be unconditional.
- Some Helm template mistakes only show up at render time → CI must run `helm template`.
- Local dev environments can generate invalid pull secrets (macOS keychain) → documented registry secret creation required.

