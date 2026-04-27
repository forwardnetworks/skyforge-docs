# Forward Demo-Fast Local Overlay

This overlay is intentionally local-only. It is for demo environments where AI
chat speed matters more than upstream-default quality settings.

It keeps the Forward request flow intact and changes only:

- BAML chat routing to cheaper Haiku paths in the local `~/src/fwd-agent` tree
- appserver direct Bedrock limits via `app.appserver.custom_settings`
- `fwd-baml-server` replica count, resources, and host spreading
- `fwd-nqe-assist` replica count, resources, and host spreading

## What this profile optimizes

- `DetermineNextStep`: non-reasoning Haiku with a small budget
- `GenerateFinalResponse`: non-reasoning Haiku capped at `1024` tokens
- `GenerateNQEQuery`: reasoning Haiku capped at `1024` tokens with a `512` thinking budget
- `SummarizeNQEResults`: non-reasoning Haiku capped at `1024` tokens
- appserver direct Bedrock path: `thinking.enabled=false`, `max_tokens=1024`

The profile deliberately avoids introducing a new semantic response cache or a
separate knowledge-tree layer. The current request flow already benefits from:

- provider-side Bedrock prompt caching in the BAML stack
- existing in-memory NQE assist request caching for bounded repeated prompts

## Overlay files

- base environment overlay: `deploy/examples/values-forward-prod.yaml`
- demo-fast overlay: `deploy/examples/values-forward-demo-fast.yaml`
- prod-shaped combined example: `deploy/examples/values-forward-prod-demo-fast.yaml`

Both the local default overlay and the prod-shaped Forward overlays now pin:

- `app.patroni.synchronous_mode=false`
- `app.patroni.synchronous_mode_strict=false`

That keeps the local/demo app tier writable if the Postgres standby drifts or
fails to reattach after a Patroni failover.

When bumping the Forward release, update the upstream Forward `app.image_version`
and the Skyforge-owned collector/worker tag together:

```bash
./scripts/set-forward-version.sh <forward-tag>
```

That keeps the Harbor `fwd_collector`, `fwd_compute_worker`, and
`fwd_search_worker` references aligned with the main Forward release tag instead
of drifting via ad hoc manual edits.

The combined example is intended to render on its own. Use it when you want a
single-file rollout. Use the two-file stack when you want to keep the demo-fast
delta visually separated from the base Forward production-shaped overlay.

## Rollout pattern

Build and push the local BAML image first, then deploy Forward using either the
single combined overlay or the explicit two-file stack.

`SKYFORGE_FORWARD_AICHAT_BAML_IMAGE_TAG` is optional. If unset, the bootstrap
flow now inherits the chart/release default BAML tag (recommended for normal
release-aligned deploys). Set it only when pinning a specific custom tag.

Single-file rollout:

```bash
cd ~/src/fwd-agent
baml-cli generate

SKYFORGE_FORWARD_OVERLAY_VALUES="deploy/examples/values-forward-prod-demo-fast.yaml" \
SKYFORGE_FORWARD_BAML_IMAGE_OVERRIDE="ghcr.io/captainpacket/fwd_baml_server:<tag>" \
SKYFORGE_FORWARD_AICHAT_BAML_IMAGE_TAG="<tag>" \
./scripts/deploy-skyforge-env.sh qa
```

Two-file rollout:

```bash
cd ~/src/fwd-agent
baml-cli generate

SKYFORGE_FORWARD_OVERLAY_VALUES="deploy/examples/values-forward-prod.yaml,deploy/examples/values-forward-demo-fast.yaml" \
SKYFORGE_FORWARD_BAML_IMAGE_OVERRIDE="ghcr.io/captainpacket/fwd_baml_server:<tag>" \
SKYFORGE_FORWARD_AICHAT_BAML_IMAGE_TAG="<tag>" \
./scripts/deploy-skyforge-env.sh qa
```

## Validation focus

After rollout, verify:

- `fwd-baml-server` has `3` replicas across multiple nodes
- `fwd-nqe-assist` has `2` replicas across multiple nodes
- appserver includes the demo Bedrock flags
- chat latency improves on the same prompt set under light concurrency

## Post-Helm self-heal guards

The local repair flow now auto-handles two common Forward failure modes after
chart upgrades:

- DB role/secret drift for both `postgres` and `postgres_non_admin`
- FDB Postgres PVC saturation from historical `pg_log/postgresql-*.csv` growth
- Patroni primary/replica service drift after failover on:
  - `fwd-pg-app`
  - `fwd-pg-fdb-0`
  - `fwd-pg-fdb-1`
- Java IPv6-only listener drift that can break IPv4 service/gateway traffic

Run:

```bash
SKYFORGE_NAMESPACE=skyforge \
SKYFORGE_FORWARD_NAMESPACE=forward \
./scripts/deploy/local/integration-repair.sh post-helm
```

Optional controls:

- `SKYFORGE_FORWARD_RECONCILE_DB_AUTH=false` disables DB auth reconcile
- `SKYFORGE_FORWARD_AUTOFIX_FDB_DISK_PRESSURE=false` disables disk-pressure cleanup
- `SKYFORGE_FORWARD_FDB_DISK_PRESSURE_THRESHOLD=95` sets the usage threshold (percent)
- `SKYFORGE_FORWARD_REPAIR_PATRONI_SERVICE_ROUTING=false` disables Patroni service endpoint repair
- `SKYFORGE_FORWARD_PATRONI_SERVICE_WAIT_SECONDS=60` controls how long the repair waits for endpoint reconciliation
- `SKYFORGE_FORWARD_FORCE_IPV4_JAVA_STACK=false` disables `_JAVA_OPTIONS=-Djava.net.preferIPv4Stack=true` enforcement

## Rollback

Rollback by redeploying without the demo-fast overlay changes and restoring the
previous BAML image tag.
