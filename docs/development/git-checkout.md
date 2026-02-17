# Git Checkout Guide (New Machine)

This is the canonical pull-only workflow to stand up Skyforge development on a new machine.
Do not copy files manually; clone from Git and sync submodules.

## Prerequisites

Install:

- `git`
- `make`
- `go` (matching `components/server` requirements)
- `node` + `pnpm`
- `helm`
- `kubectl`
- `encore` CLI

## Recommended Layout (Meta Repo + Submodules)

1. Clone meta repo:

```bash
git clone https://github.com/forwardnetworks/skyforge.git
cd skyforge
```

2. Initialize submodules:

```bash
git submodule update --init --recursive
```

3. Bootstrap local toolchain/deps:

```bash
make bootstrap
```

4. Verify all component repos are present:

```bash
git submodule status --recursive
```

Expected checkout map:

- `components/server` -> `https://github.com/forwardnetworks/skyforge-server.git`
- `components/portal` -> `https://github.com/forwardnetworks/skyforge-portal.git`
- `components/charts` -> `https://github.com/forwardnetworks/skyforge-charts.git`
- `components/docs` -> `https://github.com/forwardnetworks/skyforge-docs.git`
- `components/blueprints` -> `https://github.com/forwardnetworks/skyforge-blueprints.git`
- `vendor/netlab` -> `https://github.com/forwardnetworks/netlab.git`
- `vendor/clabernetes` -> `https://github.com/forwardnetworks/clabernetes.git`

## Optional Layout (Standalone Component Repos)

If you prefer independent sibling clones for daily development:

```bash
git clone https://github.com/forwardnetworks/skyforge-server.git
git clone https://github.com/forwardnetworks/skyforge-portal.git
git clone https://github.com/forwardnetworks/skyforge-charts.git
git clone https://github.com/forwardnetworks/skyforge-docs.git
git clone https://github.com/forwardnetworks/skyforge-blueprints.git
```

Keep the meta repo cloned as the source of truth for submodule pinning.

## Daily Sync

From meta root:

```bash
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive
```

From any component repo:

```bash
git fetch --all --prune
git pull --ff-only
```

## First-Run Validation

```bash
make test
cd components/server && ENCORE_DISABLE_UPDATE_CHECK=1 encore check ./...
cd ../portal && pnpm install && pnpm type-check
cd ../charts && helm lint skyforge
```

## Resume Existing Workstream

If you are continuing an active branch from another machine:

```bash
git branch -vv
git submodule foreach 'git branch -vv || true'
```

Then checkout the same branches in the relevant component repos and pull latest before building/deploying.
