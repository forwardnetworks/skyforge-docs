# Skyforge OSS Readiness Checklist

This checklist captures the work required to make Skyforge safe and practical to open source.

Scope: `skyforge` as the current source-of-truth. This document assumes the goal is a
public repo that can be deployed by external users without Forward Networks infrastructure.

Status keys:
- ✅ done
- 🟡 partial / in progress
- ⬜ not started

## 0) Decide the OSS “product shape”

⬜ **Core vs. integrations split**
- Define a “core” distribution that works without Forward, NetBox/Nautobot, and Gitea provisioning.
- Define optional “integration modules” (Forward sync, collector, NetBox/Nautobot SSO).

⬜ **Deployment target**
- Pick a default: supported local OSS path is single-node `k3s`.
- Decide whether to ship Helm as the primary path, or Helm + plain manifests.

⬜ **Licensing + policy**
- Choose license (Apache-2.0/MIT/etc) and add contributor guidelines (CLA or DCO).
- Define a public issue triage / security vulnerability process (private disclosure email).

## 1) Remove / isolate proprietary or internal-only dependencies

🟡 **Forward Networks integration**
- Keep as an optional module:
  - Forward API sync, collector provisioning, and credential management.
- Ensure the core system runs cleanly with Forward disabled (no required config/secrets).

⬜ **Internal hostnames / environment assumptions**
- Remove any hard-coded internal DNS names, domains, and cluster-specific URLs from:
  - docs, charts, defaults, and sample configs.
- Replace with placeholders and clear install steps.

## 2) Configuration + secrets (public-safe defaults)

🟡 **Typed config**
- Ensure all non-secret config is set via typed Encore config (`ENCORE_CFG_*`) and/or Helm values.
- Keep secrets strictly in:
  - Encore secrets (preferred), or
  - Kubernetes Secrets created by the operator.

⬜ **Provide a minimal “no-OIDC” mode**
- For OSS users without Dex/OIDC:
  - Option A: local auth (via Dex local users).
  - Option B: “OIDC required” but provide a one-command Dex example.

⬜ **Provide example configs**
- `deploy/examples/values-minimal.yaml` (no external integrations)
- `deploy/examples/values-oidc-dex.yaml`
- `deploy/examples/values-gitea.yaml` (if keeping provisioning)

## 3) Packaging (images + charts)

⬜ **Image provenance**
- Publish build scripts that produce reproducible `linux/amd64` images.
- Provide versioning/tagging guidance (semver + git sha tags).

⬜ **Helm chart hardening**
- `helm lint` + template validation in CI.
- No secrets committed; chart defaults must be safe.
- Document required RBAC for clabernetes and any exec/terminal features.

⬜ **Optional components**
- Make external tools (NetBox/Nautobot/Coder/Yaade/Collector) explicitly toggled in values.
- Core install should deploy only what’s required to run the platform.

## 4) Security review (pre-public)

⬜ **AuthN/AuthZ**
- Confirm user-scope ownership/sharing rules are enforced on every API path.
- Ensure terminal/kube-exec endpoints cannot be used to escape namespace boundaries.

⬜ **RBAC + Kubernetes safety**
- Ensure clabernetes + exec permissions are least-privilege (namespace-scoped where possible).
- Confirm delete/destroy operations are safe and idempotent.

⬜ **Secrets handling**
- Confirm no secrets are written to logs.
- Confirm no secrets are serialized into run metadata or artifacts.

⬜ **Supply chain**
- Lock down base images; document how to rebuild.
- Provide SBOM generation instructions (optional but recommended).

## 5) Documentation (external-user ready)

⬜ **Quickstart**
- A single page that gets from 0 → running UI on a laptop.
- Include troubleshooting for common issues (OIDC redirect mismatch, ingress, image pulls).

⬜ **User guide**
- Projects + deployments overview
- Deployment methods: Netlab (C9s), Containerlab, Terraform (optional)
- How to bring your own templates (Git-based)

⬜ **Operator guide**
- Upgrades
- Backups/restores (DB + object storage)
- Observability (metrics endpoints, worker health)
- Disaster recovery notes

## 6) CI / quality gates

⬜ **CI pipeline**
- `encore test ./forwardregistry ./skyforge ./worker ./internal/...`
- `go test ./cmd/...` for command binaries such as `smokecheck`
- `go test` for non-encore libs where possible
- Helm lint/template rendering
- Container image build verification

⬜ **Smoke tests**
- Provide a public smoke test that doesn’t require internal identity providers:
  - health, login, create user scope, create & destroy a basic deployment.

## 7) Public launch prep (Autocon / demos)

⬜ **Remove/replace vendor assets**
- Any vendor NOS images cannot ship in public repos.
- Provide a “bring your own images” workflow + sample open images.

⬜ **Demo topology pack**
- Provide a small set of templates that use freely available container images.
- Ensure demo works on a small cluster footprint.
