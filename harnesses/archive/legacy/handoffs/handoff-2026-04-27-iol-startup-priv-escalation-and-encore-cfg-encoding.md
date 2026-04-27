---
harness_kind: completed-exec-plan
status: completed
legacy_source: codex-handoff-2026-04-27-iol-startup-priv-escalation-and-encore-cfg-encoding.md
converted_at: 2026-04-27
archived_at: 2026-04-27
environment: prod
title: IOL startup-mode and Encore config encoding
systems_touched: Netlab runtime, KNE, prod config encoding
verification: preserved in converted legacy body
current_truth: components/docs/netlab-kne.md; components/docs/harnesses/environment-contracts.md
superseded_assumptions: see the Harness conversion notes and body sections for stale local/k3d/prod context details
archive_note: historical evidence only; use current_truth for active guidance
---

# IOL startup-mode and Encore config encoding

> Archived evidence note: this body is retained for provenance only. Use the `current_truth` frontmatter and the completed-plan stub for active guidance.
> Absorbed into active docs on 2026-04-27: IOL startup-mode and apply-limit behavior lives in `components/docs/netlab-kne.md`; prod image/context handling lives in `components/docs/harnesses/environment-contracts.md`.

# Skyforge prod handoff: IOL startup-mode + privilege-escalation + Encore config encoding

Date: 2026-04-27
Environment: prod (`arch@labpp-sales-prod01.dc.forwardnetworks.com`)

## 1) Incident summary
- Symptom in run `3121`: KNE deployment reached `netlab initial`, then IOL nodes were sent through Ansible task `deploy-config/ios.yml` and failed with:
  - `operation requires privilege escalation`
- Observed in worker logs for task `3121` even though nodes were `device iol`.

## 2) Root cause
- Runtime apply-plan correctly marks IOL nodes as startup-config in mixed topologies.
- But when any node needs generated day-0 (for example EOS/XRD in same topology), runtime executed a global `netlab initial` without host limiting.
- That global apply then included IOL nodes and hit IOS Ansible deployment path, causing privilege-escalation errors.

## 3) Code fix (local repo)
File: `components/server/netlab/runtime/netlab.py`
- Added `_resolve_netlab_initial_limit_nodes(step)` to select only `nodePlans[].source == "generated-day0"`.
- Updated `run_netlab_initial(workdir, limit_nodes=None)` to append `--limit <nodes>` unless already provided.
- Updated `_execute_apply_plan(...)` to pass the generated-day0 subset into `run_netlab_initial(...)`.

Test added:
- `components/server/netlab/runtime/netlab_runtime_test.py`
- `test_resolve_netlab_initial_limit_nodes_filters_to_generated_day0`

Local verification:
- `python3 -m unittest netlab.runtime.netlab_runtime_test.NetlabRuntimeContractTest.test_resolve_netlab_initial_limit_nodes_filters_to_generated_day0`

## 4) New netlab runtime image
Built/pushed:
- `ghcr.io/forwardnetworks/skyforge-netlab:20260427-iol-startup-limit-r1`

Build command:
- `./scripts/build-push-skyforge-netlab.sh --tag 20260427-iol-startup-limit-r1 --skip-ghcr-login`

## 5) Critical encoding trap (repeated drift source)
`ENCORE_CFG_*` secret payloads are **base64url raw (no padding)**, not standard base64.

Do not patch these blobs with standard base64 encoding.
If you do, server/worker crash with decode panics like:
- `failed to decode configuration ... illegal base64 data at input byte ...`

## 6) Safe prod update procedure for Netlab.Image in Encore config
Use this transform path:
1. Secret `.data.ENCORE_CFG_*` (k8s base64) -> decode once
2. Result is base64url-raw config blob -> decode with URL-safe base64 + padding
3. Edit JSON (`Netlab.Image`)
4. Re-encode using URL-safe base64 and strip `=` padding
5. Patch via `stringData`
6. Restart `skyforge-server` and `skyforge-server-worker`

Reference command used successfully in this session (local machine with prod kubeconfig):

```bash
python3 - <<'PY'
import base64, json, subprocess
from copy import deepcopy

K='KUBECONFIG=/tmp/kubeconfig-prod-labpp'
NEW_IMAGE='ghcr.io/forwardnetworks/skyforge-netlab:20260427-iol-startup-limit-r1'

def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True)

def decode_rawurl(s: str):
    pad='='*((4-len(s)%4)%4)
    return base64.urlsafe_b64decode((s+pad).encode()).decode()

def encode_rawurl(text: str):
    return base64.urlsafe_b64encode(text.encode()).decode().rstrip('=')

def patch_secret(name: str):
    raw=run(f"{K} kubectl -n skyforge get secret {name} -o json")
    obj=json.loads(raw)
    data=obj.get('data',{})
    string_data={}
    for key,b64v in data.items():
        if not key.startswith('ENCORE_CFG_'):
            continue
        lvl1=base64.b64decode(b64v).decode()
        try:
            payload=json.loads(decode_rawurl(lvl1))
        except Exception:
            continue
        if isinstance(payload,dict) and isinstance(payload.get('Netlab'),dict) and payload['Netlab'].get('Image'):
            payload=deepcopy(payload)
            payload['Netlab']['Image']=NEW_IMAGE
            lvl1_new=encode_rawurl(json.dumps(payload,separators=(',',':')))
            string_data[key]=lvl1_new
    if string_data:
        patch={"stringData": string_data}
        patch_json=json.dumps(patch,separators=(',',':'))
        subprocess.check_call(f"{K} kubectl -n skyforge patch secret {name} --type merge -p '{patch_json}'", shell=True)

patch_secret('skyforge-encore-cfg')
patch_secret('skyforge-encore-cfg-worker')
PY

KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge rollout restart deploy/skyforge-server deploy/skyforge-server-worker
KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge rollout status deploy/skyforge-server --timeout=240s
KUBECONFIG=/tmp/kubeconfig-prod-labpp kubectl -n skyforge rollout status deploy/skyforge-server-worker --timeout=240s
```

## 7) Recovery playbook when ENCORE_CFG gets corrupted
- Pull known-good `ENCORE_CFG_*` values from `helm get manifest -n skyforge skyforge`.
- Patch those exact values back via `stringData`.
- Restart server+worker.
- Confirm no more decode panics in logs.

## 8) Current prod state after recovery
- `skyforge-server`: Running
- `skyforge-server-worker`: Running
- Encore decoded config now points to:
  - `ghcr.io/forwardnetworks/skyforge-netlab:20260427-iol-startup-limit-r1`

## 9) Verification still pending
- I could not directly relaunch quick deploy from CLI because `/api/quick-deploy/deploy` requires a browser session cookie (basic auth returns `missing session cookie`).
- Pending operator step: launch the same quick deploy path from UI, then verify worker log for the new run:
  - `netlab initial args` should include `--limit` with generated-day0 nodes only.
  - IOL nodes should no longer hit `deploy-config/ios.yml`.
  - No `operation requires privilege escalation`.

## 10) Saved context (to avoid rediscovery)
- Prod host: `arch@labpp-sales-prod01.dc.forwardnetworks.com`
- Prod kubeconfig source on host: `/etc/rancher/k3s/k3s.yaml`
- Local working kubeconfig copy used here: `/tmp/kubeconfig-prod-labpp`
- Public hostname: `https://skyforge.dc.forwardnetworks.com`
