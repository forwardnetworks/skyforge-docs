# Designer EVE-NG Parity Migration and Import Flexibility

Last updated: 2026-04-11

## Objective

Deliver broad lab-authoring parity in Designer while keeping deployment launches on the KNE-native path, and make topology import extensible across multiple source formats.

## Current Implementation Status

- KNE-native deployment path remains the only launch path for Designer.
- Generic import API is implemented at:
  - `POST /api/users/:id/deployments-designer/kne/import`
- Source support:
  - `containerlab`: enabled
  - `eve-ng`: planned (returns blocking `source-not-enabled`)
  - `gns3`: planned (returns blocking `source-not-enabled`)
- Designer import UI now uses source selection and clearly marks planned sources as disabled.
- Designer import dialog now shows deterministic conversion feedback: blocking/ready status, issue counts/list, unsupported features, and image mapping count.
- Import source handling now uses an adapter registry in server code, so new source parsers (EVE-NG/GNS3) can be enabled without endpoint contract churn.
- Designer palette now merges enabled Registry & NOS Catalog rows with discovered registry repos (excluding explicitly disabled catalog rows), so uncataloged NOS images remain available on the left.
- Designer palette now includes a direct workflow link to `/settings?section=integrations` for adding registry locations and NOS catalog entries.
- Admin Registry & NOS Catalog now exposes coverage counters (discovered, cataloged, missing, disabled) and a one-click action to seed missing discovered repos into catalog draft rows.
- Playwright smoke coverage now includes deploy-launch request acceptance from an imported two-node topology, gated by `SKYFORGE_SMOKE_ALLOW_DEPLOY=1`.
- Save flow now writes optional sidecar metadata as `*.designer.json` next to `*.kne.yml`; import from user templates now attempts sidecar rehydrate (`GET /api/users/:id/kne/designer-sidecar`) to restore canvas metadata (node/link editor state and viewport) without changing KNE deployment artifacts.
- Sidecar save now preserves unknown/non-core keys on round-trip (for future annotations/groups/layout extensions) while still updating canonical fields (`version`, `labName`, `defaultKind`, `viewport`, `nodes`, `edges`).
- Lab inspector now includes first-class editors for sidecar-backed `annotations` and `groups` artifacts.
- Canvas now renders sidecar-backed annotations/groups as overlays, including projected annotation positions and group active-node counts.
- Source adapters are now enabled for `eve-ng` and `gns3` with native conversion paths to KNE Designer YAML.
- Import source selector labels now reflect enabled `EVE-NG` and `GNS3` conversion paths (no planned-only label).
- Import result panel now includes explicit manual follow-up hints for common conversion warnings/errors (multi-access expansion, skipped links, missing images, validation warnings).
- Import converters now warn on unsupported infra/node semantics and non-Ethernet interface mappings instead of failing opaque, and skip unsupported cloud/NAT/bridge helper nodes deterministically.
- Import converters now emit explicit `link-endpoints-skipped` warnings when external/unmapped endpoints are dropped during link conversion.
- EVE converter now emits `management-network-ignored` when `network_id=0` attachments are ignored during import.
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
| Topology import | Generic import dialog works for containerlab and reports clear errors for planned sources | Required |
| Deploy launch | Designer launch reaches KNE `ready` state for smoke topology | Required |

## Next Migration Steps

1. Extend import coverage for additional EVE-NG/GNS3 constructs (for example management cloud semantics and non-point-to-point topologies) while preserving deterministic KNE output.
2. Run full live Playwright smoke parity on deployed environment and capture pass/fail evidence by feature area.
   - Local baseline run currently skips all smoke tests when required env vars are unset.
