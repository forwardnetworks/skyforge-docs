# Forward On-Prem Integration

Skyforge exposes Forward on-prem UI via `/fwd`.

## Notes

- `/fwd` is a compatibility proxy path.
- Route rewrites and cookie path handling are chart-configured.
- Changes to Forward UI/API paths require proxy regression checks.

## Validation

At minimum, validate:

- `/fwd/`
- login/logout path behavior
- key settings/search deep-links
