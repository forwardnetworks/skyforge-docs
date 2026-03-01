# Template Validation (Netlab / Containerlab / Terraform)

Skyforge ships a large blueprint catalog. To reduce demo-time surprises, we validate templates
offline (no cluster required) and expose a Netlab “Validate” action in the UI.

## Netlab

### Node naming requirement (C9s)

For C9s-backed runs, node names in `topology.yml` must be valid DNS-1035 labels:

- lowercase only
- 1-63 characters
- start with a letter (`a-z`)
- end with an alphanumeric character (`a-z0-9`)
- allowed characters are `a-z`, `0-9`, and `-`

This rule is enforced by the netlab `k8s` plugin in the runtime validation path (`netlab create`).

### UI

On `Dashboard → Deployments → Create`, select a Netlab template and click **Validate**.
This runs `netlab create` inside the Netlab runtime image, without deploying anything.

### CLI (bulk validate all Netlab templates)

From `skyforge/`:

```bash
python3 scripts/validate_netlab_templates.py > /tmp/netlab-validate-report.md
```

Notes:
- This uses the netlab runtime image configured in `components/charts/skyforge/values.yaml` (`skyforge.netlab.image`).
- It mirrors Skyforge template listing behavior:
  - root-level `*.yml|*.yaml` files are treated as single-file templates
  - nested templates must be `topology.yml|topology.yaml`
  - excludes output/inventory folders like `host_vars/`, `group_vars/`, `node_files/`, etc.

### Known unsupported Netlab templates

As of 2026-01-24, the validator still reports failures for a small set of templates that require
either:
- custom config templates not currently included in the repo (for example `loopback`, `bgp-ipv6`, `bgp-anycast`), or
- licensed images/features not currently bundled (SR Linux ixr6 license), or
- Netlab plugins/features that are not compatible with the generator’s pinned Netlab version.

These are expected to fail validation until we either update the runtime image Netlab version or
refactor the templates:

- `BGP/Multi-Loopback/topology.yml`
- `BGP/Multipath_sros/topology.yml`
- `DHCP/evpn-relay-v2/topology.yml`
- `DMVPN/topology.yml`
- `multi-platform/cyber-crane-mesh/topology.yml`
- `plugins/adjust-bgp-sessions/topology.yml`
- `plugins/adjust-config-template/topology.yml`
- `routing/sr-isis-te/topology.yml`
- `routing/sr-mpls-bgp-srlinux/topology.yml` (requires SR Linux license)

## Containerlab

We validate containerlab templates against the official containerlab JSON schema (no deploy).

For C9s-backed containerlab runs, Skyforge applies the same DNS-1035 node-name validation during
template build/preflight.

```bash
(cd server && go run ./cmd/validatecontainerlab --root ../blueprints/containerlab) > /tmp/containerlab-validate-report.md
```

## Terraform

We validate with dockerized terraform and run `init -backend=false` + `validate` against a temporary
copy to avoid writing `.terraform/` into the repo.

```bash
python3 scripts/validate_terraform_templates.py > /tmp/terraform-validate-report.md
```
