---
harness_kind: active-exec-plan
status: active
legacy_source: components/docs/plans/designer-eve-gns3-parity-migration.md
converted_at: 2026-04-27
title: Designer EVE-NG Parity Migration and Import Flexibility
current_truth: verify against current code and environment before execution
---

# Designer EVE-NG Parity Migration and Import Flexibility

Last updated: 2026-04-13

## Objective

Deliver broad lab-authoring parity in Designer while keeping deployment launches on the KNE-native path, and make topology import extensible across multiple source formats.

## Current Implementation Status

- KNE-native deployment path remains the only launch path for Designer.
- Generic import API is implemented at:
  - `POST /api/users/:id/deployments-designer/kne/import`
- Source support:
  - `containerlab`: enabled
  - `eve-ng`: enabled
  - `gns3`: enabled
- Designer import UI is now split into two flows:
  - load saved template
  - import external topology
- External topology import is now a staged wizard:
  - upload topology file
  - auto-detect source from filename/content with manual override
  - convert on the backend
  - review node/link stats, warnings, unsupported nodes, and image mappings
  - explicitly replace the current canvas
- External import no longer mutates the canvas during conversion preview. Replacement only happens after explicit confirmation.
- Import API now returns `detectedSource`, `canImport`, and import `stats` so the review step can render deterministic readiness and warning summaries.
- Import source handling now uses an adapter registry in server code, so new source parsers (EVE-NG/GNS3) can be enabled without endpoint contract churn.
- Designer palette is now catalog-only. The left palette shows only enabled Registry & NOS Catalog rows and no longer falls back to built-in preset NOS entries or uncataloged discovered repos.
- Designer palette now includes a direct workflow link to `/settings?section=integrations` for adding registry locations and NOS catalog entries.
- Admin Registry & NOS Catalog now exposes coverage counters (discovered, cataloged, missing, disabled) and a one-click action to seed missing discovered repos into catalog draft rows.
- Playwright smoke coverage now includes deploy-launch request acceptance from an imported two-node topology, gated by `SKYFORGE_SMOKE_ALLOW_DEPLOY=1`.
- Save flow now writes optional sidecar metadata as `*.designer.json` next to `*.kne.yml`; import from user templates now attempts sidecar rehydrate (`GET /api/users/:id/kne/designer-sidecar`) to restore canvas metadata (node/link editor state and viewport) without changing KNE deployment artifacts.
- Sidecar save now preserves unknown/non-core keys on round-trip (for future annotations/groups/layout extensions) while still updating canonical fields (`version`, `labName`, `defaultKind`, `viewport`, `nodes`, `edges`).
- Designer sidecar node metadata now persists structured startup config state:
  - `mode=path`
  - `mode=inline`
  - optional preserved import metadata for placeholder nodes
- Lab inspector now includes first-class editors for sidecar-backed `annotations` and `groups` artifacts.
- Canvas now renders sidecar-backed annotations/groups as overlays, including projected annotation positions and group active-node counts.
- Source adapters are now enabled for `eve-ng` and `gns3` with native conversion paths to KNE Designer YAML.
- Import result panel now includes explicit manual follow-up hints for common conversion warnings/errors (multi-access expansion, placeholder nodes, missing images, validation warnings).
- Import converters now preserve unsupported infra/helper nodes as placeholder designer nodes instead of dropping them when the topology graph is still usable.
- Missing image and similar per-node mapping problems are now warnings instead of blocking failures as long as the imported graph remains structurally usable.
- EVE converter now emits `management-network-ignored` when `network_id=0` attachments are ignored during import.
- Designer-authored KNE YAML no longer emits `runtime: containerlab`. Runtime is preserved only when it is semantically meaningful for KNE, such as VM/KubeVirt nodes.
- Designer validation no longer requires `runtime` for normal container-based KNE nodes.
- Startup config is now a first-class designer contract:
  - `path` mode round-trips existing `startup-config` references
  - `inline` mode materializes deterministic files under `.designer-startup/<template-base>/<node>.cfg` at save time
- Added fixture-backed server import parity samples under `components/server/skyforge/testdata/lab_designer_import/` for EVE-NG and GNS3 paths.
- GNS3 JSON export input is now explicitly covered in conversion tests (not only YAML-shaped samples).
- Playwright designer smoke now includes GNS3 JSON import conversion coverage, using shared import fixtures.
- Added Playwright import topology fixture module at `components/portal/tests/playwright/fixtures/import-topologies.ts` and wired smoke import tests to use shared fixtures.

## Parity Matrix (Wave 1 Gate)

| Area | Expected Behavior | Gate |
| --- | --- | --- |
| Canvas authoring | Add/edit/delete/duplicate nodes and links is deterministic | Required |
| Pane controls | Header/palette/inspector collapse and focus mode persist per session | Required |
| Link editing | Interface/label/MTU/notes edits persist after reselection | Required |
| Quickstart | Deterministic generated node/link counts for fixed input | Required |
| YAML round-trip | Custom YAML toggle and round-trip works | Required |
| Template import | Import from blueprints/user templates into canvas model works | Required |
| Topology import | Saved-template load remains simple; external import uses preview-then-replace wizard semantics | Required |
| Deploy launch | Designer launch reaches KNE `ready` state for smoke topology | Required |

## Next Migration Steps

1. Extend import coverage for additional EVE-NG/GNS3 constructs (for example management cloud semantics and non-point-to-point topologies) while preserving deterministic KNE output.
2. Run full live Playwright smoke parity on deployed environment and capture pass/fail evidence by feature area.
   - Local baseline run currently skips all smoke tests when required env vars are unset.
