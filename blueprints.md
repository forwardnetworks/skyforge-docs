# Blueprints repository

Skyforge uses a **blueprints** Git repository as the canonical catalog for:

- Lab templates (EVE‑NG)
- Containerlab / Netlab templates
- Cloud Terraform starter modules (AWS/Azure/GCP)

Deployments reference these templates by **repo + folder path**; Skyforge does not need to copy templates into each workspace.

```mermaid
flowchart LR
  user([User]) --> ui[Skyforge Portal]
  ui --> api[Skyforge Server]

  api -->|references| bp[Blueprints repo<br/>skyforge/blueprints]
  api -->|creates| proj[Workspace repos<br/>{user}/{workspace}]
  api --> runner[Native task engine<br/>(Tofu / Netlab / LabPP / Containerlab)]

  runner -->|clones| proj
  runner -->|optionally clones| bp
  runner --> s3[S3 artifacts + state]
  runner --> labs[EVE‑NG / Netlab / Containerlab]
```

## Recommended folder scheme

Keep the catalog predictable so the UI can offer sensible defaults:

- `cloud/terraform/aws/…`
- `cloud/terraform/azure/…`
- `cloud/terraform/gcp/…`
- `labpp/<template-name>/…` (blueprints repo)
- `blueprints/labpp/<template-name>/…` (workspace repo override)
- `netlab/<template>.yml`
- `containerlab/<template>.yml`

Skyforge deployments store the selected **repo** and **templates folder** (repo-relative), then discover templates underneath.

Notes:

- LabPP templates are directories (each subfolder is a template).
- Netlab templates are YAML topology files (each `.yml` / `.yaml` file is a template).
- Containerlab templates are YAML topology files (each `.yml` / `.yaml` file is a template).
- Project repos can keep templates under `blueprints/labpp/...`, `blueprints/netlab/...`, and `blueprints/containerlab/...` for workspace-scoped customization.
- LabPP templates must include `lab.json`. Skyforge syncs the selected LabPP template to the EVE‑NG host at `/var/lib/skyforge/labpp-templates/<template>` on each run.

## Bootstrap options

The simplest approach is to create the `blueprints` repo manually in your Git
provider and push the catalog once:

```bash
git remote add gitea https://<hostname>/git/skyforge/blueprints.git
git push gitea HEAD:main
```

To make the blueprint catalog visible to everyone, set the repo visibility to public in Gitea:

- Gitea UI: `skyforge/blueprints` → Settings → "Make Repository Public"
