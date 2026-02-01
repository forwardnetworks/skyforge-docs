# Device-type E2E tests (Netlab + Containerlab)

This doc describes the **device-type** end-to-end tests implemented in `skyforge-private/server/cmd/e2echeck`.

Goal: quickly answer **“do the device types we ship actually work?”** (template validates, and optionally deploys + accepts SSH).

## What’s covered

### Default scope: onboarded device types

By default, the E2E matrix targets a curated list of “onboarded” device types (what Skyforge exposes in the UI / what we expect to work in-cluster).

- Use `SKYFORGE_E2E_DEVICE_SET=all` to instead generate tests from the upstream Netlab catalog (`internal/taskengine/netlab_device_defaults.json`).
- `vsrx` is explicitly excluded (out of scope).

### Default depth: validate-only

By default the matrix contains **only `netlab_validate` tests**. Deploy tests are **opt-in** because they are slow.

- Enable in-cluster deploy + SSH probe with `SKYFORGE_E2E_DEPLOY=true`.
- Limit which device types are deployed with `SKYFORGE_E2E_DEPLOY_DEVICES=...`.

### Optional depth: advanced routing templates

Enable additional templates (OSPF + BGP) with:

```bash
export SKYFORGE_E2E_ADVANCED=true
```

These templates exist under the shared blueprint catalog as:

- `netlab/_e2e/minimal/topology.yml`
- `netlab/_e2e/routing-ospf/topology.yml`
- `netlab/_e2e/routing-bgp/topology.yml`

They are auto-seeded into the `skyforge/blueprints` repo by Skyforge bootstrap.

## Running locally against Skyforge (in-cluster)

From `skyforge-private/server`:

```bash
go run ./cmd/e2echeck --generate-matrix > /tmp/skyforge-e2e-matrix.json
```

### Validate device types (fast)

```bash
export SKYFORGE_E2E_MATRIX_FILE=/tmp/skyforge-e2e-matrix.json
export SKYFORGE_E2E_DEPLOY=false
go run ./cmd/e2echeck --run-generated
```

### Deploy + SSH probe (slow)

```bash
export SKYFORGE_E2E_MATRIX_FILE=/tmp/skyforge-e2e-matrix.json
export SKYFORGE_E2E_DEPLOY=true
export SKYFORGE_E2E_DEPLOY_DEVICES=eos,iol,iosv
go run ./cmd/e2echeck --run-generated
```

Notes:

- SSH probing uses a Kubernetes Job by default (`SKYFORGE_E2E_SSH_PROBE_MODE=job`).
- If your local `kubectl` can’t reach the cluster, run the E2E command *from a Skyforge node* (or fix kube access) so `kubectl` works.

## BYOS runners (netlab.local.forwardnetworks.com)

Enable BYOS tests (Netlab + Containerlab) with:

```bash
export SKYFORGE_E2E_BYOS=true
export SKYFORGE_E2E_BYOS_NETLAB_API_URL=https://netlab.local.forwardnetworks.com/netlab
```

The E2E runner will configure the workspace’s Netlab server list via the Skyforge API before launching a BYOS deployment.

