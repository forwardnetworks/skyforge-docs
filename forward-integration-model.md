# Skyforge ↔ Forward Integration Model (Proposed)

This document outlines a model for connecting Skyforge deployments (netlab-c9s/clabernetes/labpp/byos) to Forward (network creation + classic device onboarding) without tying the configuration to a single workspace.

## Goals

- Avoid re-entering Forward credentials per workspace.
- Support multiple concurrent workspaces per user.
- Work with in-cluster (c9s) deployments without inbound connectivity requirements.
- Keep secrets local to Skyforge (stored server-side; never committed).

## Recommendation: per-user Forward profile + in-cluster collector

### 1) Per-user Forward profile (preferred scope)

Store these per authenticated user:

- Forward base URL (`https://app.forwardnetworks.com` or equivalent).
- Forward API token (or username/password if required).
- Preferred collector (optional) if using a shared collector fleet.

Why per-user:
- A user’s Forward account is independent of a particular workspace.
- Workspaces often come/go; the integration should persist.

### 2) In-cluster Forward Collector (preferred data-plane)

For deployments that live in the Kubernetes cluster (netlab-c9s/clabernetes), the simplest and most reliable approach is to run a Forward collector **inside the cluster**:

- One collector per user (recommended), or one collector per workspace (simpler isolation).
- The collector establishes outbound connectivity to Forward, and uses in-cluster networking to reach the device management IPs (pod IPs / services).

Benefits:
- No inbound firewall/NAT requirements.
- No jump/bastion required to reach pod IPs.

## BYOS: external devices / remote lab servers

For Bring-Your-Own-Server deployments (devices live outside the cluster), you typically need an additional “reachability bridge” from the collector to the devices.

Two options:

### Option A (recommended): collector runs near the devices

- User runs their own collector on the same network as their lab devices.
- Skyforge only pushes device inventory (IP, port, type hints, credentials).

### Option B: Skyforge provides a jump/bastion endpoint

- Skyforge deploys a per-user (or per-workspace) SSH bastion inside the cluster and exposes it (NodePort/LoadBalancer/cloudflared TCP).
- The collector (outside) uses the bastion as a jump host to reach internal device addresses.

Tradeoffs:
- More operational complexity (exposure, auth, rotation).
- Requires careful isolation to avoid cross-tenant access.

## Suggested UX

- **User settings**: “Forward Integration”
  - Configure token and (optional) collector preference.
  - Test connection.
- **Deployment run**: uses the user’s Forward profile by default.
  - Still allow overrides (advanced) per workspace/deployment if needed.

## Implementation sketch (high level)

1) Persist per-user Forward credentials in `sf_users`-adjacent table (encrypted at rest).
2) When a deployment run reaches “sync to Forward”:
   - Ensure a collector exists (if in-cluster model).
   - Create/ensure Forward network.
   - Upsert classic devices with best-effort type hints where known.
3) Store Forward network ID in deployment config for later updates/destroy.

