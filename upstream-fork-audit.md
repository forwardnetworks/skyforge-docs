# Upstream Fork Audit (2026-02-22)

This document captures the current fork status for the Skyforge vendored projects and the integration cleanup gates required for clean PRs and deploy parity.

## Clabernetes

- Fork branch: `forwardnetworks/clabernetes:skyforge-upstreamable-vxlan`
- Upstream base: `srl-labs/clabernetes:main`
- Drift status: `0 behind / 13 ahead`
- Current pinned SHA in Skyforge: `631706e0bb9a7e582bb697808b73d6c4d6f12dd4`

### Included ahead commits

- non-conflicting launcher/serviceaccount/config-hash reliability fixes
- vxlan native-mode tunnel/link setup fix
- scheduling-affinity topology spec extension
- tunnels-file env constant and hash baseline test alignment

### Excluded changes

- all Multus/NAD behavior (hard-cut)
- historical conflict-heavy patch set not directly cherry-picked (to be rewritten only if proven critical)

### Validation

- `go test` passed for all non-e2e packages
- no active Multus/NAD references in runtime CRD/controller paths

## Netlab

- Fork branch: `forwardnetworks/netlab:skyforge-dev`
- Upstream base: `ipspace/netlab:dev`
- Rebased and pushed (force-with-lease)
- Current pinned SHA in Skyforge: `3ffea28452aa3101768a94ec64e4f47412543947`

### Retained custom deltas

- NXOS lag/vpc support
- zonebased firewall plugin enhancements
- upstream sync workflow file

## Skyforge integration legacy audit

### Kept intentionally

- provider-native cloud semantics such as `accountId` and `projectId`

### Removed/blocked

- Multus runtime integration path

### Remaining high-churn cleanup

- `Workspace*` API operation naming in server and portal-generated client symbols (hard-cut migration planned)

## Clean PR and deployment gates

A cleanup cycle is considered complete when all of the following are true:

1. Fork PRs are repo-split (`clabernetes`, `netlab`, `skyforge-*`, then meta pin).
2. Skyforge submodule SHAs are pinned to reviewed fork commits.
3. Build/tests pass:
   - clabernetes non-e2e `go test`
   - server targeted `go test`
   - charts `helm lint`
4. Deployment uses the same SHAs/tags referenced in PRs.
5. Post-deploy smoke validates deploy/run/topology/forward-sync happy paths.
