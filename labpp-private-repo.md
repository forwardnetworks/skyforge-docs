# LabPP: split into a private repo

Goal:
- Keep **Skyforge core** in `github.com/forwardnetworks/skyforge` (eventually public).
- Move **LabPP / EVE-NG integration + runner + any proprietary artifacts** into a **separate private repo**.
- Skyforge core should still *compile and deploy* with LabPP disabled.

## What should move
At minimum:
- `labpp-runner/`
- Any bundled LabPP CLI sources / artifacts (for example, `fwd/` snapshots or vendor JARs).
- Any server-side LabPP task execution code that depends on the above artifacts.
- Helm chart bits required only for LabPP (Secrets keys, env vars, optional jobs).
- `blueprints/labpp/` (if we decide those are proprietary; otherwise keep public examples in core).

## What stays in the core repo
- DB schema support for `deployment.type=labpp` **only if it does not require proprietary code**.
- UI support gated behind a feature flag:
  - LabPP method should be hidden unless `labpp.enabled=true`.
- Optional proxy plumbing (`labppProxy`) can stay if it’s generic and doesn’t leak internals.

## How to split (recommended workflow)
We want the split to preserve history and keep the fork maintainable.

### Option A (best): `git filter-repo` (history-preserving)
1. Create a new empty private repo (example): `forwardnetworks/skyforge-labpp-private`.
2. In this repo, run `git filter-repo` from a clone of `skyforge-private/` to extract LabPP paths.
3. Add minimal README + build/deploy docs for the LabPP runner image.

### Option B: `git subtree split` (simpler, but less flexible)
Use `scripts/split-labpp-repo.sh` to produce a branch containing only LabPP paths, then push it to a new repo.

## Integration contract (core ↔ labpp-private)
Keep this boundary small and stable:
- Core calls LabPP via:
  - A worker task type (enqueue + status + artifacts)
  - A runner image reference (private)
  - Optional external EVE proxy config
- All private images (LabPP runner, proprietary dependencies) are referenced via Helm values and can be disabled.

## OSS/packaging implications
- Core should not require any private GHCR creds if LabPP is disabled.
- If LabPP is enabled:
  - user supplies an imagePullSecret + runner image tag (private registry ok).

