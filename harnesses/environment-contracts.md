# Environment Contracts

This file is the agent-facing map for QA/prod assumptions. The full runbook is
[../environment-profiles.md](../environment-profiles.md).

## Context guard

Always use the environment context scripts before deploy or environment
automation:

```bash
./scripts/set-skyforge-context.sh qa
./scripts/show-skyforge-context.sh
```

Deploy commands fail closed when context, values file, URL profile, or remote
host do not match. Break-glass context bypass exists but must be explicit and
single-command scoped.

If `SKYFORGE_TARGET_ENV` is unset, `scripts/lib/environment-context.sh` may
infer the target from `VALUES_FILE`. That inference is intentionally
fail-closed:

- QA context rejects prod values files.
- Prod context rejects QA values files.
- Hostname and public URL mismatches block deploy unless an explicit
  single-command break-glass override is present.

Fast revalidation:

```bash
./scripts/show-skyforge-context.sh
VALUES_FILE=deploy/skyforge-values-qa.yaml ./scripts/show-skyforge-context.sh
VALUES_FILE=deploy/skyforge-values-prod-labpp-sales-prod01.yaml ./scripts/show-skyforge-context.sh
```

## QA

- Skyforge: `https://skyforge.local.forwardnetworks.com`
- Forward: `https://skyforge-fwd.local.forwardnetworks.com`
- Expected Skyforge DNS/VIP: `10.128.16.80`
- Host: `arch@skyforge-worker-0`
- Kubeconfig source on host: `/etc/rancher/k3s/k3s.yaml`
- Deploy env: `deploy/environments/qa.env`
- Deploy command: `SKYFORGE_ALLOW_PROD_DEPLOY=true ./scripts/deploy-skyforge-env.sh qa`

Health check:

```bash
curl -skS -o /tmp/skyforge_qa_health.json \
  -w '%{http_code} %{remote_ip} %{time_total}\n' \
  https://skyforge.local.forwardnetworks.com/api/health
jq -c . /tmp/skyforge_qa_health.json
```

## Production

- Skyforge: `https://skyforge.dc.forwardnetworks.com`
- Forward: `https://skyforge-fwd.dc.forwardnetworks.com`
- Expected Skyforge DNS/VIP: `10.128.65.100`
- Host: `arch@labpp-sales-prod01.dc.forwardnetworks.com`
- Kubeconfig source on host: `/etc/rancher/k3s/k3s.yaml`
- Local working kubeconfig commonly used by operators: `/tmp/kubeconfig-prod-labpp`
- Deploy env: `deploy/environments/prod.env`
- Deploy command: `SKYFORGE_ALLOW_PROD_DEPLOY=true ./scripts/deploy-skyforge-env.sh prod`

Prod is a single-node deployment on `labpp-sales-prod01`; do not use QA
hostnames, QA kubeconfig contexts, or `captainpacket` SSH assumptions for prod.

Health check:

```bash
curl -skS -o /tmp/skyforge_prod_health.json \
  -w '%{http_code} %{remote_ip} %{time_total}\n' \
  https://skyforge.dc.forwardnetworks.com/api/health
jq -c . /tmp/skyforge_prod_health.json
```

## Live-change rule

Before changing routing, Gateway API, Helm state, control-plane reachability, or
public hostnames, state the change and restore path. Do not leave the public
Skyforge hostname returning `404`, `5xx`, or a known broken SPA/API route state
when a safe restore is available.

## Netlab image preservation

When rolling server/worker images, preserve the live `skyforge.netlab.image`
unless intentionally changing the Netlab runtime. Verify live Helm values first.

Prod image rollouts should carry the server, worker, and netlab image contracts
explicitly so a role/UI rollout cannot accidentally downgrade the netlab runtime:

```bash
SKYFORGE_SERVER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:<api-tag> \
SKYFORGE_SERVER_WORKER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:<worker-tag> \
SKYFORGE_NETLAB_IMAGE="$(KUBECONFIG=/tmp/kubeconfig-prod-labpp \
  helm -n skyforge get values skyforge -o json | jq -r '.skyforge.netlab.image')" \
SKYFORGE_ALLOW_PROD_DEPLOY=true \
  ./scripts/deploy-skyforge-env.sh prod
```

If a prod deploy hits server-side apply ownership conflicts from runtime
patches, the deploy script may retry with `--force-conflicts`. Treat that as
acceptable only when the final Helm release is `deployed` and rollout/image
checks pass.

## Stateful Backup Guard

Existing QA/prod releases must not recreate stateful PVCs during deploy. The
deploy script now fails closed before Helm if critical PVCs such as `db-data`,
`platform-data`, `skyforge-server-data`, `redis-data`, `gitea-data`, or
`s3gw-data` are missing or unbound. Use `SKYFORGE_ALLOW_STATEFUL_RECREATE=true`
only as a single-command break-glass override after taking an explicit backup.

Existing releases also require a fresh non-empty Postgres backup before Helm:

```bash
find /var/lib/skyforge/local-backups/skyforge-backups/postgres \
  /mnt/hetzner-wireguard/skyforge-backups/skyforge-worker-0/skyforge-backups/postgres \
  -maxdepth 1 -type f -name 'skyforge-postgres-*.sql.gz' \
  -printf '%TY-%Tm-%Td %TT %s %p\n' | sort | tail
```

The `backup-postgres-s3` CronJob owns the dump and object-store upload. The
`backup-local-spread` DaemonSet mirrors `s3gw` backups to node-local storage,
and `backup-offsite-raw` mirrors that local root to the offsite mount. If a
restore replaces `s3gw-data`, rerun the CronJob or a Helm upgrade so the
`skyforge-backups` bucket is recreated before the next nightly backup.

For QA only, older chart history can leave workload controllers that Kubernetes
cannot patch in place, such as Forward volume mount `subPath` drift or immutable
StatefulSet volume specs. Do not use release-wide Helm force replacement for
Skyforge because the release owns bound PVCs. Replace only the stale workload
controllers, preserve PVCs, and rerun the normal environment deploy.

## Local AI harness routing

Use the local AI harness for token-saving read-only delegation, and verify all
routes after changing Codex/RTK config:

```bash
rtk ai-local "return LOCAL_OK"
rtk ai-gemini "return GEMINI_OK"
rtk ai-claude "return CLAUDE_OK"
rtk ai-delegate local "return DELEGATE_LOCAL_OK"
rtk ai-delegate gemini "return DELEGATE_GEMINI_OK"
rtk ai-delegate claude "return DELEGATE_CLAUDE_OK"
```

Delegate output is advisory; verify important claims with local files,
commands, tests, or live APIs before acting.
