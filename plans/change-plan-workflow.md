# Change Plan Workflow

## Purpose

Skyforge change control now treats a change as a reviewed `change-plan` run
instead of a direct push primitive.

The workflow is the same for both supported deploy backends:

- `netlab-kne`
- `ansible-push`

The difference is what the execution step does.

## End-to-End Flow

1. Create a `change-plan` run against a deployment target.
2. Render the run into a normalized review payload.
3. Review the planned execution path, artifacts, and Forward verification scope.
4. Approve the run.
5. Execute it through the worker task engine.
6. Verify it against Forward and capture final evidence.

## Step 1: Create

The operator creates a run with:

- `targetType=deployment`
- `targetRef=<deployment-id>`
- `sourceKind=change-plan`
- `executionMode=dry-run|staged|apply`
- `specJson=<change plan payload>`

Example `netlab-kne` plan:

```json
{
  "name": "edge-routing-change",
  "description": "promote validated edge routing intent",
  "deploy": {
    "backend": "netlab-kne",
    "templateSource": "blueprints",
    "template": "BGP/Default-NH/topology.yml",
    "environment": {
      "DEVICE": "eos"
    }
  },
  "verify": {
    "backend": "forward",
    "networkId": "network-123",
    "checks": ["Critical reachability"],
    "diffCategories": ["devices", "checks"]
  }
}
```

Example `ansible-push` plan:

```json
{
  "name": "edge-acl-push",
  "description": "apply ACL change to the running KNE deployment",
  "deploy": {
    "backend": "ansible-push",
    "devices": ["leaf-1", "leaf-2"],
    "playbook": "---\n- hosts: all\n  gather_facts: false\n  tasks: []"
  },
  "verify": {
    "backend": "forward",
    "networkId": "network-123",
    "checks": ["Critical reachability"],
    "diffCategories": ["devices", "checks"]
  }
}
```

Example `ansible-push` using a playbook already present in the deployment bundle:

```json
{
  "name": "edge-acl-push",
  "deploy": {
    "backend": "ansible-push",
    "devices": ["leaf-1", "leaf-2"],
    "playbookSource": "bundle-file",
    "playbookPath": "automation/push.yml"
  },
  "verify": {
    "backend": "forward",
    "networkId": "network-123",
    "checks": ["Critical reachability"]
  }
}
```

## Step 2: Render

Render normalizes the spec and produces a review payload.

Render output includes:

- execution path
- execution backend
- verification backend
- device scope
- rendered artifacts
- warnings

For `netlab-kne`, the review describes a planned topology/template deployment.

For `ansible-push`, the review describes:

- the target device list
- the generated runtime-hook artifact
- the playbook artifact path
- the fact that execution still runs through the KNE/netlab worker seam

## Step 3: Review

Review is where the operator verifies:

- the deployment target is correct
- the backend is correct
- the device scope is correct
- the Forward verification target is correct
- the planned artifacts match expectation

For `ansible-push`, review should answer:

- which KNE deployment is being targeted
- which devices will be limited via Ansible `--limit`
- where the playbook came from:
  - inline plan payload
  - existing bundled file path
- which Forward checks and diff categories will be used after execution
- whether `verify.autoRollback` is eligible for this backend:
  - `netlab-kne`: eligible and enforced on verification failure
  - `ansible-push`: marked unsupported in review output

## Step 4: Approve

Approval transitions the run from `awaiting-approval` to `approved`.

Only approved deployment-targeted `change-plan` runs are executable in apply or
staged mode.

## Step 5: Execute

### `netlab-kne`

Execution updates the deployment config/template context and runs the existing
KNE/netlab deployment worker path.

### `ansible-push`

Execution does not create a new topology.

Instead it:

1. loads the existing KNE deployment
2. builds the deployment's netlab bundle/inventory context
3. injects the playbook as a bounded runtime hook
4. limits the playbook to the requested devices
5. runs the existing worker seam

That means `ansible-push` is "operate on this live KNE deployment using its
generated inventory", not "redeploy a new lab".

## Step 6: Evidence And Verification

Before apply, when `verify.backend=forward`, Skyforge resolves the target
Forward network and stores the latest processed snapshot as the verification
baseline when one exists.

After apply, Skyforge captures:

- task id
- topology artifact key
- node status evidence
- per-device execution summary
- execution backend
- verification backend
- artifact references

During the verify phase, when `verify.backend=forward`, Skyforge performs real
Forward calls:

1. resolve `verify.networkId`, or fall back to the deployment's tracked Forward
   network id
2. list processed snapshots for that network
3. capture the latest snapshot as the post-change verification target
4. run each requested embedded check against that post-change snapshot
5. persist snapshot refs, check refs, and verification warnings in the run
   execution summary

Current Forward verification behavior:

- `checks`: executed for real during verify
- `networkId`: resolved and persisted in evidence
- `diffCategories`: executed as baseline-vs-post snapshot deltas by running all
  embedded checks in each requested category
- `autoRollback`: on verification failure, automatically rolls back only for
  rollback-eligible change plans (`netlab-kne` backend)
  Auto-rollback outcomes are recorded in execution warnings and artifacts.

Portal evidence surfaces:

- Review card shows `verify.autoRollback` plan eligibility from rendered artifacts.
- Execution Summary shows the latest auto-rollback outcome badge and reason.
- Selected Run shows latest auto-rollback outcome/reason in the run detail card.
  It also shows an explicit rollback-blocked reason when rollback is disabled.
  Execution backend is shown even pre-execution via rendered review metadata.
- Queue view supports auto-rollback outcome badges and outcome filters.
  It also surfaces pre-execution `autoRollback` requested/eligibility state.
  Requested state filters can isolate eligible vs unsupported plans.
- Lifecycle view shows an auto-rollback summary tile and the latest correlated
  lifecycle event when available.

Verification fails the run if:

- Forward credentials are unavailable
- the target Forward network cannot be resolved
- Forward snapshot lookup fails
- a requested Forward check cannot be executed
- a Forward check returns one or more findings
- a requested diff category cannot be executed (for example missing baseline
  snapshot or check execution failure)

## Rollback Semantics

Rollback support is backend-specific.

- `netlab-kne`: supported through the captured deployment baseline
- `ansible-push`: not supported today

`ansible-push` rollback is blocked intentionally because the current rollback
model captures deployment/topology baseline, not arbitrary device running-config
preimages.

## Operational Summary

Use `netlab-kne` when the change is a deployment/template/topology mutation.

Use `ansible-push` when the KNE deployment already exists and you want to run an
Ansible change against that live inventory inside the same controlled workflow.
