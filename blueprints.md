# Blueprints repository

Skyforge uses a **blueprints** Git repository as the canonical catalog for:

- Lab templates (EVE‑NG)
- Containerlab / Netlab templates
- Cloud Terraform starter modules (AWS/Azure/GCP)

Deployments reference these templates by **repo + folder path**; Skyforge does not need to copy templates into each project.

```mermaid
flowchart LR
  user([User]) --> ui[Skyforge Portal]
  ui --> api[Skyforge Server]

  api -->|references| bp[Blueprints repo<br/>skyforge/blueprints]
  api -->|creates| proj[Project repos<br/>{user}/{project}]
  api --> sem[Semaphore templates/tasks]

  sem -->|clones| proj
  sem -->|optionally clones| bp
  sem --> runner[Runner container<br/>(Tofu / Netlab)]

  runner --> s3[S3 artifacts + state]
  runner --> labs[EVE‑NG / Netlab]
```

## Recommended folder scheme

Keep the catalog predictable so the UI can offer sensible defaults:

- `cloud/terraform/aws/…`
- `cloud/terraform/azure/…`
- `cloud/terraform/gcp/…`
- `blueprints/labpp/<template-name>/…`
- `blueprints/netlab/<template>.yml`

Skyforge deployments store the selected **repo** and **templates folder** (repo-relative), then discover templates underneath.

Notes:

- LabPP templates are directories (each subfolder is a template).
- Netlab templates are YAML topology files (each `.yml` / `.yaml` file is a template).
- You can also keep templates in a project repo under the same paths (`blueprints/labpp/...`, `blueprints/netlab/...`) for project-scoped customization.

## Bootstrap options

The simplest approach is to create the `blueprints` repo manually in your Git
provider and push the catalog once:

```bash
git remote add gitea https://<hostname>/git/skyforge/blueprints.git
git push gitea HEAD:main
```

To make the blueprint catalog visible to everyone, set the repo visibility to public in Gitea:

- Gitea UI: `skyforge/blueprints` → Settings → "Make Repository Public"
