# Template Repository (Git-native)

Skyforge uses a shared Git repository as the template catalog:

- Repo: `skyforge/netlab-examples`
- Managed directly in Gitea with normal Git workflows
- Referenced directly by deployments (no per-user blueprint copy/sync)

```mermaid
flowchart LR
  user([User/Admin]) --> git[Gitea repo<br/>skyforge/netlab-examples]
  user --> ui[Skyforge Portal]
  ui --> api[Skyforge Server]
  api -->|references templates by repo+path| git
  api --> runner[Native task engine<br/>(Netlab/Containerlab/EVE/Tofu)]
```

## Folder scheme

Keep templates at repo root:

- `netlab/...`
- `containerlab/...` (optional)
- `terraform/...` (optional)
- `eve-ng/...` (optional)

## DNS-safe automation

The catalog repo includes a Gitea Action workflow:

- `.gitea/workflows/dns-normalize.yml`

It runs:

- `tools/normalize_dns_safe.py`

On every push and auto-commits DNS-1035-safe node name fixes.

## Bootstrap

```bash
git clone https://<host>/git/skyforge/netlab-examples.git
cd netlab-examples
# edit templates
git add -A
git commit -m "update templates"
git push
```

To keep it visible in Explore:

- Gitea UI: `skyforge/netlab-examples` -> Settings -> "Make Repository Public"
