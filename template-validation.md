# Template Validation (Netlab / Containerlab / Terraform)

Skyforge ships a large blueprint catalog. To reduce demo-time surprises, we validate templates
offline (no cluster required) and expose a Netlab “Validate” action in the UI.

## Netlab

### UI

On `Dashboard → Deployments → Create`, select a Netlab template and click **Validate**.
This runs `netlab create` inside the Netlab generator image, without deploying anything.

### CLI (bulk validate all Netlab templates)

From `skyforge-private/`:

```bash
python3 scripts/validate_netlab_templates.py > /tmp/netlab-validate-report.md
```

Notes:
- This uses the generator image configured in `deploy/skyforge-values.yaml` (`skyforge.netlabC9s.generatorImage`).
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

These are expected to fail validation until we either update the generator’s Netlab version or
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

We do lightweight validation (YAML schema sanity checks) without trying to deploy.

```bash
python3 scripts/validate_containerlab_templates.py > /tmp/containerlab-validate-report.md
```

## Terraform

We validate with dockerized terraform and run `init -backend=false` + `validate` against a temporary
copy to avoid writing `.terraform/` into the repo.

```bash
python3 scripts/validate_terraform_templates.py > /tmp/terraform-validate-report.md
```

