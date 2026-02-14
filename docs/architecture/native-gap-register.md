# Native Gap Register (2026-02-14)

This register tracks pragmatic-native drift that still exists and the required follow-up actions.

## 1) Forward on-prem proxy complexity

Current state:

- `components/charts/skyforge/templates/forward-app-proxy.yaml` contains extensive route-specific rewrite logic.

Why this is a gap:

- High maintenance surface for upstream Forward UI/API changes.

Planned remediation:

1. Move route coverage to a declarative allowlist model.
2. Keep integration tests that validate login, settings, and deep-link routes.
3. Reduce template branch complexity release-by-release.

## 2) Vendor fork drift

Current state:

- `vendor/netlab` and `vendor/clabernetes` are pinned to custom branches.

Why this is a gap:

- Upgrade/rebase cost increases over time.

Planned remediation:

1. Keep branch + SHA policy in `vendor/VENDOR_POLICY.md`.
2. Require compatibility evidence with each SHA bump.
3. Periodically evaluate upstream merge feasibility.

## 3) Embedded frontend artifact handling

Current state:

- Portal build artifacts are synchronized into server frontend distribution paths.

Why this is a gap:

- Requires consistent, policy-driven handling to avoid stale hashes.

Planned remediation:

1. Keep artifact policy documented in `docs/governance/frontend-dist-policy.md`.
2. Retain CI checks for stale/duplicate entry assets.

## 4) Documentation governance

Current state:

- Docs were reset to a public-safe v1 baseline.

Follow-up:

1. Expand v1 docs only from implementation-backed behavior.
2. Keep `scripts/public-docs-gate.sh` passing for all changes.
