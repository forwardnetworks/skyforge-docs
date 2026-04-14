# Template Validation (Netlab / KNE / Terraform)

Skyforge ships a large blueprint catalog. To reduce demo-time surprises, we validate templates
offline (no cluster required) and expose a Netlab “Validate” action in the UI.

## Netlab

### Node naming (KNE)

For KNE-backed runs, the netlab KNE plugin normalizes node names to DNS-1035
labels during `netlab create` generation. Manual pre-normalization in templates
or Gitea workflows is no longer required.

### UI

On `Dashboard → Deployments → Create`, select a Netlab template and click **Validate**.
This runs `netlab create` inside the Netlab runtime image, without deploying anything.

For `User repo` templates, the create flow also supports **Upload YAML/ZIP**:

- upload a zip archive containing a template folder
- Skyforge writes the extracted files into the user repo under `netlab/uploaded/<name>/...`
- `topology.yml` or `topology.yaml` is required at the template root (or as the only YAML file in the uploaded folder)
- referenced sidecar files such as `startup-config`, generated config snippets, and similar text artifacts must be present in the uploaded archive
- binary payloads are rejected in this flow; keep template uploads to text files and config sidecars

Validation is now a hard launch gate for Netlab-backed create/deploy flows:

- invalid templates are rejected before a run is queued
- the UI returns structured diagnostics with suggested fixes for common failure classes:
  - missing `topology.yml`
  - provider mismatch (`kne` vs non-`kne`)
  - missing images
  - missing sidecar files such as `startup-config`
  - YAML/schema/attribute errors
  - repo/path resolution failures
  - temporary validator infrastructure failures

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

## KNE

We validate kne templates against the official kne JSON schema (no deploy).

For KNE-backed kne runs, Skyforge continues to apply DNS-1035 checks
during template build/preflight.

```bash
(cd server && go run ./cmd/validatekne --root ../blueprints/kne) > /tmp/kne-validate-report.md
```

## Terraform

We validate with dockerized terraform and run `init -backend=false` + `validate` against a temporary
copy to avoid writing `.terraform/` into the repo.

```bash
python3 scripts/validate_terraform_templates.py > /tmp/terraform-validate-report.md
```
