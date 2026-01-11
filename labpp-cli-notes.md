# LabPP CLI Notes

Skyforge runs LabPP directly via the stock `fwd` CLI (`gradlew runFwdPlusCli`), not through the legacy LabPP API.

## Runtime expectations
- The `fwd` repo is bundled into the skyforge-server image at `/opt/skyforge/fwd`.
- LabPP templates are synced locally to `/var/lib/skyforge/labpp-templates/<template>`.
- LabPP config files are written under `/var/lib/skyforge/labpp-configs`.

## Required environment
- `SKYFORGE_LABPP_FWD_ROOT` (default `/opt/skyforge/fwd`)
- `SKYFORGE_LABPP_CONFIG_DIR_BASE` (default `/var/lib/skyforge/labpp-configs`)
- `SKYFORGE_LABPP_NETBOX_URL`
- `SKYFORGE_LABPP_NETBOX_USERNAME`
- `SKYFORGE_LABPP_NETBOX_PASSWORD`
- `SKYFORGE_LABPP_NETBOX_MGMT_SUBNET`

Skyforge writes `fwd/test/configs/labpp/net_box_server_config.json` at runtime so LabPP can resolve NetBox settings for the selected EVE host.

## Actions
Skyforge maps deployment actions to LabPP CLI actions:
- `create` → `UPLOAD`
- `start` → `START`
- `stop` → `STOP`
- `destroy` → `DELETE`
- `info` uses EVE-NG API status only
- `run` (default) → `DEFAULT` (LabPP E2E flow)

## Forward integration
Skyforge owns Forward sync; LabPP should not require or attempt any Forward configuration.

After a successful run, Skyforge generates `data_sources.csv` and uses it to register devices with Forward.

### `data_sources.csv` format
- Desired: `name,ip_address` (management IPv4) with port `22` implied.
- LabPP may emit: `name,ip_address,ssh_port` where `ip_address` is the EVE host and `ssh_port` is a per-device forwarded port.

To keep Forward jump-server behavior consistent, Skyforge rewrites the generated CSV to `name,ip_address` using the management IPv4s reserved by LabPP/NetBox during the run.

## Status (2026-01-11)
LabPP core flow is functional end-to-end:
- Template sync → LabPP run → NetBox allocations → `data_sources.csv` generation → Forward network creation + device upload.

Known follow-ups remain (non-blocking), but the primary LabPP deployment workflow is working.
