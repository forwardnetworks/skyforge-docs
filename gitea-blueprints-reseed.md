# Reseed the public `skyforge/blueprints` repo (Gitea)

Skyforge expects the public blueprints repo (`skyforge/blueprints`) to contain top-level template folders like:

- `netlab/…`
- `eve-ng/…`
- `containerlab/…`
- `terraform/…`

If template pickers show “No templates” and the Skyforge server is healthy, it usually means the Gitea repo contents are missing or incomplete.

## Prod (skyforge)

1) Create a temporary git repo from the `blueprints/` directory contents:

```bash
cd skyforge-private
rm -rf /tmp/skyforge-blueprints-seed
mkdir -p /tmp/skyforge-blueprints-seed
rsync -a --delete blueprints/ /tmp/skyforge-blueprints-seed/
cat > /tmp/skyforge-blueprints-seed/README.md <<'EOF'
# Skyforge Blueprints

This repository contains public starter templates (“blueprints”) used by Skyforge.

Source-of-truth: the `blueprints/` directory in the private Skyforge repo.
EOF

cd /tmp/skyforge-blueprints-seed
git init
git checkout -b main
git add .
git -c user.email=skyforge@local -c user.name=skyforge commit -m "Seed blueprints"
```

2) Push it to Gitea (force-push):

- Remote: `https://skyforge.local.forwardnetworks.com/git/skyforge/blueprints.git`
- Auth: use the configured Gitea admin credentials (`SKYFORGE_GITEA_USERNAME` + `SKYFORGE_GITEA_PASSWORD`).

One non-interactive approach is `GIT_ASKPASS` with `GIT_TERMINAL_PROMPT=0`.

## QA (skyforge-qa)

If `skyforge-qa.local.forwardnetworks.com` isn’t reachable from your workstation, port-forward Gitea through the QA cluster and push over `http://127.0.0.1:<port>`.

Example:

```bash
KUBECONFIG=.kubeconfig-skyforge-qa kubectl -n skyforge port-forward svc/gitea 13000:3000 --address 127.0.0.1
```

Then use:

- Remote: `http://127.0.0.1:13000/skyforge/blueprints.git`

## Notes

- This is intentionally a force-push: the repo is treated as a published catalog, and `skyforge-private/blueprints/` remains the source-of-truth.
- Keeping the top-level layout (`netlab/…`, not `blueprints/netlab/…`) is required for the “Blueprints” template source to work without extra path prefixes.
