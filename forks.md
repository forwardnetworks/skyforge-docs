# Fork maintenance (Netlab + Clabernetes)

Skyforge intentionally vendors **very little**. When we must patch upstream projects to fit our deployment model, we do it as a fork with a minimal delta and a clear upgrade path.

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

Netlab is installed into the netlab generator image from:

- `netlab/generator/requirements.txt` (git URL pinned to a commit)
- Generator image built/pushed to GHCR
- Helm values set `skyforge.netlabC9s.generatorImage`

### Updating netlab in Skyforge

1) Merge/push changes to `forwardnetworks/netlab`.
2) Bump the pin in `netlab/generator/requirements.txt`.
3) Build and push a new generator image:

```bash
cd skyforge-private/netlab/generator
docker buildx build --platform linux/amd64 \
  -t ghcr.io/forwardnetworks/skyforge-netlab-generator:<tag> \
  --push .
```

4) Update `deploy/skyforge-values.yaml` to point to the new `generatorImage`.
5) Deploy QA then prod (see `docs/deploy-qa-then-prod.md`).

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

- `deploy/skyforge-values.yaml` (prod)
- `deploy/skyforge-values-qa.yaml` (QA)

### Building/pushing clabernetes images

Skyforge uses custom images (built from the fork) under the `ghcr.io/forwardnetworks/` org, for example:

- `ghcr.io/forwardnetworks/skyforge-clabernetes-manager:<tag>`
- `ghcr.io/forwardnetworks/skyforge-clabernetes-launcher:<tag>`

Build/push and then bump the Helm values to match.

## Template validation gates

Before any QA deploy, run:

```bash
cd skyforge-private
scripts/preflight-packaging.sh
```
