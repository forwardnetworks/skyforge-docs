# Deferred: Hetzner K3s Networking Evaluation

Status: Deferred for later implementation.

## Context

We paused the Hetzner cloud networking work while focusing on ServiceNow and
current local/prod deployment hardening.

## Decision Questions To Revisit

1. For multi-node Skyforge on Hetzner without guaranteed L2 adjacency, should
   Cilium run in pure L3 mode (`routing-mode=native`) with BGP/route
   distribution?
2. Is the Hetzner-native k3s path (Cloud Controller Manager + CSI + no L2
   assumptions) sufficient for our clabernetes/kubevirt workloads?
3. What is the preferred exposure model for Gateway API/Envoy in Hetzner:
   managed LB per Gateway vs node-local + external LB?
4. Which traffic classes must remain east-west only vs publicly exposed?

## Planned Validation

1. Build a minimal Hetzner k3s test cluster with the same Skyforge charts and
   feature flags as current k3d/prod.
2. Validate pod-to-pod, service, and Gateway API routing across nodes under L3.
3. Validate clabernetes data-plane requirements (Multus/VXLAN paths) for
   container and kubevirt NOS nodes.
4. Confirm failure behavior during node reboot/replacement and route
   convergence.
5. Decide and document the standard Hetzner profile values file.

## Exit Criteria

- Documented, reproducible Hetzner deployment profile.
- Clear Cilium routing mode choice with rationale.
- Verified Skyforge + clabernetes workload behavior on that profile.
