# Execution Plans

- `active/`: resumable work that is still in progress.
- `completed/`: compact completed-work stubs with `current_truth` and
  `archive_path` metadata.
- `../archive/legacy/`: full historical bodies and old notes retained for
  evidence only.

Do not create root-level handoff files. New handoffs start in `active/` and move
to `completed/` when verified. If the handoff body is pure history after its
facts are absorbed, archive the full body under `../archive/legacy/` and leave a
short completed stub.
