# Skyforge Maintainer Guide

This guide tracks the work required to keep Skyforge portable and modular.
The intent is to keep internal/proprietary modules optional, while ensuring
the core platform remains runnable and useful to downstream users.

## Goals

- Make Skyforge runnable without vendor-specific infrastructure.
- Keep proprietary modules isolated (not required to build/run).
- Publish clear deployment paths for local dev and Kubernetes.

## Optional/Internal Modules (Initial)

- Internal lab integrations and any org-specific runtime dependencies.

## Current Direction

- Provide a portable-first configuration profile.
- Keep provider integrations pluggable and optional.
- Document internal-only pieces so they can be removed or replaced.
- Configuration inputs are documented in `docs/configuration.md` (UI branding, hostnames, admin email).

## Next Steps

- Introduce a feature flag or build tag for proprietary modules.
- Ensure shared docs do not reference internal-only services.
