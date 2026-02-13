# Workspace Layout (Canonical)

Skyforge development in this environment uses a **multi-repo sibling layout** under:

- `/home/ubuntu/Projects/skyforge`

The **canonical day-to-day root** is:

- `/home/ubuntu/Projects/skyforge/skyforge`

Run all meta-repo commands (`make bootstrap`, `make test`, helper scripts) from that path.

## Active repositories at the workspace parent root

- `skyforge` (meta repo)
- `skyforge-server`
- `skyforge-portal`
- `skyforge-charts`
- `skyforge-docs`
- `skyforge-blueprints`

## What is considered clutter

These are generated or duplicate parent-level artifacts and should not be treated as source-of-truth:

- Netlab-generated artifacts: `group_vars/`, `host_vars/`, `node_files/`, `hosts.yml`, `ansible.cfg`, `clab-augment.yml`, `netlab.snapshot.pickle`, `Vagrantfile`
- Duplicate plain dirs at parent root: `components/`, `docs/`, `internal/`, `netlab/`, `server/`, `charts` (symlink)

## Cleanup policy

Use the cleanup script from the meta repo:

```bash
cd /home/ubuntu/Projects/skyforge/skyforge
./scripts/ops/workspace-cleanup.sh --mode audit --profile aggressive
./scripts/ops/workspace-cleanup.sh --mode apply --profile aggressive
```

The script archives moved items under:

- `/home/ubuntu/Projects/skyforge/archive/cleanup-<timestamp>/`

This gives deterministic rollback while keeping the active workspace root clear.
It also cleans common generated netlab artifacts that accidentally appear inside
`skyforge-blueprints/` (for example `group_vars/`, `host_vars/`, `node_files/`).

## Netlab source of truth

For Skyforge runtime image defaults and behavior, use the tracked server image paths in `skyforge-server`.
Do not treat parent-level unversioned `netlab/` as canonical.
