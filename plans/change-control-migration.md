# Change Control Migration

## Summary

Skyforge config changes are moving from direct push-oriented source kinds to a
plan-oriented workflow.

The intended operator path is now:

1. create a `change-plan` run
2. render and review it
3. approve it
4. execute it through the worker task engine
5. verify it with Forward-backed evidence

## Why

The previous config push model was centered on netlab bundle mutation and
runtime hooks. That was useful as a narrow execution seam, but it was not the
right product shape for broader change control.

The new model keeps the durable lifecycle, approval flow, queueing, task
execution, and rollback evidence, but changes the unit of work from "push this
snippet or hook" to "execute this reviewed change plan".

## Current Backends

`change-plan` currently supports:

- `netlab-kne`
- `ansible-push`

Both backends still execute through the existing `netlab-kne` worker seam. This
keeps the deployment worker and task evidence path intact while removing the old
push-centric contract from the UI.

The `ansible-push` backend packages the supplied playbook as a bounded runtime
hook inside the same bundle-backed seam. It is intentionally execution-only for
now; the current rollback model does not capture enough device pre-change state
to safely roll back arbitrary Ansible pushes.

Forward verification is now partially live for `change-plan` runs:

- baseline snapshot capture happens before apply
- post-change snapshot lookup happens during verify
- requested embedded Forward checks run against the post-change snapshot
- requested `diffCategories` run baseline-vs-post category deltas using
  embedded checks mapped from the Forward catalog
- `autoRollback` is now enforced for verification failures on rollback-eligible
  change plans (`netlab-kne` backend)
  Auto-rollback outcomes are persisted in run execution evidence.

`autoRollback` remains unsupported for `ansible-push`.

Future backends should plug into the same change-plan lifecycle:

- `forward-verify-only`
- other native deployment backends as needed

## Impact

- portal config-change creation now defaults to `change-plan`
- server render and execution now accept `change-plan`
- legacy source kinds remain in code for compatibility with old records, but
  they are no longer the intended path
