# TODO: Replace Longhorn + MinIO with SeaweedFS

This document tracks the migration plan to simplify storage by using **SeaweedFS** for:

- Persistent volumes (PV/PVC replacement for workloads that need POSIX-like storage)
- S3-compatible object storage (replacement for MinIO)

## Goals

- Reduce operational complexity (fewer moving parts than Longhorn + MinIO).
- Keep Skyforge install/recovery **repeatable** (fresh cluster install should work every time).
- Preserve required semantics:
  - RWX support where needed
  - S3 API compatibility for artifacts
  - Reasonable HA/recovery behavior

## Current State (Today)

- Longhorn provides PV/PVC (RWO + RWX via share-manager where configured).
- MinIO provides S3-compatible bucket(s) used for artifacts/topology snapshots.
- Gitea currently uses a PVC (`gitea-data`).

## Target State (SeaweedFS)

### 1) S3 / Object storage

- [ ] Install SeaweedFS and enable S3 gateway.
- [ ] Configure Skyforge object storage to point at SeaweedFS S3 endpoint.
- [ ] Migrate buckets/objects from MinIO → SeaweedFS.
- [ ] Remove MinIO chart components and health checks.

### 2) PV/PVC replacement (optional / phase 2)

We can do this in phases:

- Phase 2A: Keep Longhorn PVs, only replace MinIO with SeaweedFS S3.
- Phase 2B: Replace Longhorn PVs with SeaweedFS filer-backed CSI (if needed).

## Gitea: “Backed by S3, not a PVC”

Gitea can store some assets in object storage, but **the repo storage itself is normally filesystem-based**.
If we want “Gitea backed by S3”, we need to be precise about what’s meant:

- Option A: Keep repo storage on PV (preferred) and use S3 for attachments/LFS/releases.
- Option B: Store repos on a filesystem exposed by SeaweedFS filer (still looks like a filesystem to Gitea).

TODOs:

- [ ] Decide which approach we want for Gitea repository storage.
- [ ] If Option A: configure Gitea for S3 for attachments/LFS/artifacts only.
- [ ] If Option B: use SeaweedFS filer CSI/volume for repo dir and remove Longhorn PVCs.

## Implementation Checklist

- [ ] Choose SeaweedFS install method (Helm chart + pinned versions).
- [ ] Add `deploy/values-seaweedfs.yaml` (or a `components.seaweedfs.enabled` toggle) for packaging.
- [ ] Define secret model (access keys, endpoints, TLS/skipTLS).
- [ ] Add smoke test: write/read object + list bucket.
- [ ] Migration script/runbook:
  - export from MinIO
  - import to SeaweedFS
  - validate object counts/checksums
- [ ] Update docs/runbooks and QA redeploy drill.

## Open Questions

- Do we need RWX semantics beyond artifacts? (Today: `platform-data`, `skyforge-server-data` are RWX).
- What is our durability/replication requirement across nodes?
- Do we need bucket lifecycle policies/versioning?

