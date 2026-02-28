# Fork maintenance (Netlab + Clabernetes)

Skyforge intentionally vendors **very little**. When we must patch upstream components to fit our deployment model, we do it as a fork with a minimal delta and a clear upgrade path.

## Goals

- Keep our fork diffs **small and reviewable**.
- Prefer configuration (values/defaults) over code changes.
- Pin Skyforge builds to **specific commits/tags** of the fork.
- Use QA-first rollout to validate changes before prod.

## Netlab fork

Repository: `github.com/forwardnetworks/netlab`

### Policy

- Only accept changes that unblock our supported Skyforge workflows (netlab → clabernetes, single-file templates, supported NOS images).
- Keep changes localized (device feature flags + missing templates) so upstreaming remains possible.

### Where Skyforge pins netlab

Netlab runtime is pinned through:

- `vendor/netlab` submodule SHA (`forwardnetworks/netlab`, branch `skyforge-dev`)
- Runtime image `ghcr.io/forwardnetworks/skyforge-netlab-generator:<tag>`
- Helm values:
  - `components/charts/skyforge/values.yaml`
  - `components/charts/skyforge/values-prod-skyforge-local.yaml`

### Updating netlab in Skyforge

Manual one-shot refresh (recommended):

```bash
cd skyforge
./scripts/refresh-netlab-runtime-from-upstream.sh
```

This script performs the full atomic update:

1) fast-forwards `vendor/netlab` (`skyforge-dev`) from `upstream/dev`
2) pushes the fork branch update
3) regenerates `components/server/internal/taskengine/netlab_device_defaults.json`
4) builds/pushes a new runtime image
5) bumps all runtime image pins in Helm + Encore config defaults

Automation:

- Workflow: `.github/workflows/netlab-runtime-refresh.yml`
- Trigger: weekly schedule + manual dispatch
- Output: PR with submodule pointer, regenerated defaults, and image pin bumps

## Clabernetes fork

Upstream: `github.com/srl-labs/clabernetes`

Fork (target): `github.com/forwardnetworks/clabernetes`

### Creating the fork repo (one-time)

If the fork repo doesn’t exist yet, have an org admin create it:

```bash
gh repo create forwardnetworks/clabernetes --private --source https://github.com/srl-labs/clabernetes
```

Then add the remote:

```bash
cd ~/Projects/skyforge/clabernetes
git remote add fork https://github.com/forwardnetworks/clabernetes
git fetch fork
```

### Policy

- Keep Skyforge-specific logic out of clabernetes when possible (Skyforge should adapt inputs).
- If a controller change is required for correctness (reconcile stability, node lifecycle, etc.), keep it tightly scoped and upstreamable.

### Local workflow (syncing upstream → fork)

Assuming you have both remotes:

```bash
cd ~/Projects/skyforge/clabernetes
git remote add upstream https://github.com/srl-labs/clabernetes
git remote add fork https://github.com/forwardnetworks/clabernetes

git fetch upstream
git checkout main
git merge --ff-only upstream/main

# Apply minimal commits on top (or rebase your topic branch)
git checkout skyforge-patches
git rebase upstream/main

git push fork skyforge-patches
```

### Where Skyforge pins clabernetes

We ship clabernetes as images (manager + launcher). Helm values control the image tags:

- `skyforge.clabernetes.managerImage`
- `skyforge.clabernetes.launcherImage`

Update them in:

- `components/charts/skyforge/values.yaml` (base/defaults)
- `components/charts/skyforge/values-prod-skyforge-local.yaml` (prod override example)

### Building/pushing clabernetes images

Skyforge uses custom images (built from the fork) under the `ghcr.io/forwardnetworks/` org, for example:

- `ghcr.io/forwardnetworks/skyforge-clabernetes-manager:<tag>`
- `ghcr.io/forwardnetworks/skyforge-clabernetes-launcher:<tag>`

Build/push and then bump the Helm values to match.

## Template validation gates

Before any QA deploy, run:

```bash
cd skyforge
scripts/preflight-packaging.sh
```
