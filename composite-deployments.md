# Composite Deployments (Design)

Skyforge today models a deployment as a single provider run (Terraform, Netlab/Containerlab, LabPP, etc). For multi-provider demos and real workflows, we want a **composite deployment** that can orchestrate multiple providers as one “deployment” with shared state, ordering, and consistent UX.

This doc describes the intended model for a composite that combines:
- **On‑prem containerlab/netlab** (running on a host like `tsa-eve-ng-001`)
- **Cloud Terraform** (AWS/Azure/GCP)
- A **tunnel/interconnect** so cloud resources and on‑prem lab nodes can reach each other.

## Concept: Two Resource Planes + Interconnect

Think in terms of:
- **Cloud plane**: VPC/VNet, subnets, security groups, transit gateway/VPN gateway, instances, etc.
- **On‑prem lab plane**: containerlab/netlab topology with mgmt subnet(s), services, and optionally traffic generators.
- **Interconnect**: a VPN/overlay link between those planes plus routing and firewall rules.

The interconnect can be implemented in multiple ways:
- WireGuard (site-to-site or “cloud gateway” + on‑prem gateway container)
- IPsec (strongSwan, cloud-managed VPN)
- Tailscale/Headscale subnet router
- SSH-based tunnels (good for quick demos, limited for routing)

## Desired UX

One deployment shows:
- A single **Create / Start / Stop / Destroy** lifecycle
- A single run history with step-level status
- Outputs and useful links for each phase (e.g. cloud console links)

## Proposed Execution Model

A composite deployment has an ordered set of **stages**. Each stage is a provider action with inputs and outputs.

Example stages:
1. `terraform.apply` (provision cloud network + VPN endpoint)
2. `tunnel.up` (establish on‑prem side of the tunnel)
3. `netlab.up` or `containerlab.up` (bring up the on‑prem lab)
4. `post.configure` (optional: configure routes, register devices, Forward sync, etc)

The composite should support:
- **Dependencies**: stage B waits for stage A outputs
- **Idempotency**: “Start” skips completed work when safe
- **Partial failure semantics**: later “best effort” steps don’t necessarily fail the whole run

## Output Passing (“Connection Facts”)

Terraform produces “connection facts” needed by later stages:
- Tunnel peer IPs / endpoint address
- Pre-shared keys / WireGuard public keys
- Routes (cloud CIDRs, on‑prem CIDRs)
- Security group rules (allowed ports)

On‑prem stages consume these facts to:
- Create tunnel config (`wg0.conf`, IPsec config, Tailscale auth key)
- Install routes (static or BGP)
- Validate reachability (health checks)

Implementation detail:
- Store stage outputs in task metadata (or a dedicated `deployment_outputs` table) so later stages can read them.
- Treat sensitive values (keys/PSKs) as encrypted secrets (reuse the existing secret box pattern).

## Routing Strategy

The on‑prem lab usually has a mgmt subnet (e.g. `192.168.X.0/24`) plus optional data-plane subnets.

To connect to cloud:
- Add routes in the cloud (to reach on‑prem subnets via the VPN attachment)
- Add routes on-prem (to reach cloud subnets via the tunnel)
- Restrict with security groups/firewalls to only required demo ports (SSH, SNMP, app ports).

Optional enhancement:
- Use BGP over the tunnel for dynamic route exchange (useful when lab CIDRs vary per run).

## Where the Tunnel Runs

We need a stable “gateway” execution point:
- **On‑prem gateway**: the netlab/containerlab host (or a dedicated lab node acting as gateway).
- **Cloud gateway**: cloud VPN gateway or an instance acting as WireGuard/strongSwan endpoint.

Skyforge should treat tunnel setup as a provider stage with a clear responsibility:
- Generate config
- Apply config to the gateway
- Validate readiness

## Implementation Notes (Incremental)

We already have:
- A task/run model with step logs
- Provider-specific runners (Terraform/Netlab/LabPP)
- A consistent way to record logs and metadata

To implement composites without rewriting everything:
- Represent a composite run as a task whose “runner” executes provider sub-steps sequentially.
- Keep sub-step logs in the same task log stream (prefix per stage).
- Optionally add “child tasks” later if we want per-stage run objects in the UI.

## Open Questions

- How to expose stage outputs in the UI (per-stage “Outputs” panel vs one merged view)?
- Which tunnel type do we standardize first (WireGuard vs IPsec vs Tailscale)?
- Do we want reusable “connection templates” per workspace (like variable groups)?

