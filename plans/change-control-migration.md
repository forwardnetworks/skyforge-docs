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

## Current Backend

The first migration slice still executes `change-plan` runs through the
`netlab-kne` worker seam. This keeps the existing deployment worker and task
evidence path intact while removing the old push-centric contract from the UI.

Future backends should plug into the same change-plan lifecycle:

- `ansible-push`
- `forward-verify-only`
- other native deployment backends as needed

## Impact

- portal config-change creation now defaults to `change-plan`
- server render and execution now accept `change-plan`
- legacy source kinds remain in code for compatibility with old records, but
  they are no longer the intended path
