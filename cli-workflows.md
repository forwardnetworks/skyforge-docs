# CLI Workflows (Skyforge + Forward)

Skyforge operational testing is CLI-first.

## Build tools

From `skyforge` root:

```bash
make tools-skyforge-cli-build
make tools-fwd-cli-build
```

- `tools-skyforge-cli-build` builds `../skyforge-cli/bin/skyforge-cli`
- `tools-fwd-cli-build` builds `../fwd-cli/bin/fwd-cli`

## Post-deploy smoke

```bash
SKYFORGE_BASE_URL="https://<hostname>" \
SKYFORGE_SMOKE_USERNAME="admin" \
SKYFORGE_SMOKE_PASSWORD="<password>" \
SKYFORGE_SMOKE_RUN_ACTION_CHECK=true \
SKYFORGE_SMOKE_SCOPE="deploy-forward" \
SKYFORGE_SMOKE_SERVER_TIMEOUT_SECONDS=240 \
SKYFORGE_CLI_BIN="../skyforge-cli/bin/skyforge-cli" \
./scripts/post-deploy-smoke.sh
```

The authenticated smoke path now runs:

- server-native `components/server/cmd/smokecheck` for `deploy-forward`
- `skyforge-cli` remains available for direct operator/stress workflows

Useful suite/stress options:

- `--template <path>` to pin one blueprint (no auto-selection)
- `--strict-forward` to fail on Forward `collectionError` devices
- `--assert-config --assert-stanzas auto|none|<csv>` for running-config checks
- `--debug-artifacts` for deeper run/node logs
- `skyforge-cli smoke stress --cycles <n>` for repeat create/destroy reliability

## Direct operator flow

```bash
cd ../skyforge-cli
./bin/skyforge-cli --profile ops --base-url https://<hostname> --insecure \
  --username admin auth login --password-stdin < <(printf '%s' "$SKYFORGE_SMOKE_PASSWORD")

./bin/skyforge-cli --profile ops deploy templates --user <scope-id> --source blueprints
./bin/skyforge-cli --profile ops deploy create --user <scope-id> --name smoke \
  --template-source blueprints --template EVPN/ebgp/topology.yml
./bin/skyforge-cli --profile ops deploy action --user <scope-id> --deployment <deployment-id> --action create
./bin/skyforge-cli --profile ops runs list --user <scope-id>
./bin/skyforge-cli --profile ops forward deploy-sync --user <scope-id> --deployment <deployment-id>
```
