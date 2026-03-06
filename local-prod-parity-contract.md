# Local k3d vs Prod Parity Contract

Local `k3d` is intentionally modeled as:

- the shared prod-shaped Skyforge platform base, plus
- a thin local overlay, plus
- staged local-only additions that are not promoted yet.

The goal is to avoid functional drift between local and prod. The local environment should not grow its own architecture.

## Baseline

Local deploys use:

- chart defaults: `components/charts/skyforge/values.yaml`
- prod-shaped base: `components/charts/skyforge/values-prod-skyforge-local.yaml`
- local overlay: `deploy/examples/values-k3d-dev.yaml`

`scripts/deploy-skyforge-local.sh` enforces this contract with:

```bash
./scripts/check-k3d-parity.py \
  components/charts/skyforge/values.yaml \
  components/charts/skyforge/values-prod-skyforge-local.yaml \
  deploy/examples/values-k3d-dev.yaml
```

If the local overlay starts overriding fields outside the approved list, the deploy fails.

For release gating, also run:

```bash
./scripts/check-prod-promotion-readiness.py \
  components/charts/skyforge/values.yaml \
  components/charts/skyforge/values-prod-skyforge-local.yaml \
  deploy/examples/values-k3d-dev.yaml
```

See `components/docs/prod-promotion-checklist.md` for pre-prod and prod promotion gates.

## Required parity surface

The merged chart defaults plus prod-shaped base must keep these enabled:

- `skyforge.forward.enabled=true`
- `skyforge.forwardCluster.enabled=true`
- `skyforge.netbox.enabled=true`
- `skyforge.nautobot.enabled=true`
- `skyforge.clabernetes.enabled=true`
- `skyforge.redoc.enabled=true`

This keeps the local cluster aligned with the prod platform surface.

## Approved local-only overrides

The local overlay may override only the following fields:

- `skyforge.auth.mode`
- `skyforge.adminUsers`
- `skyforge.gateway.addresses`
- `skyforge.debug.ssoProxyAccessLog`
- `skyforge.dex.manageConfig`
- `skyforge.dex.authMode`
- `skyforge.oidc.discoveryUrl`
- `skyforge.oidc.issuerUrl`
- `skyforge.oidc.redirectUrl`
- `skyforge.infoblox.enabled`
- `skyforge.infoblox.internalUrl`
- `skyforge.infoblox.upstreamHost`
- `skyforge.infoblox.upstreamPort`
- `skyforge.infoblox.lanNetworkName`
- `skyforge.infoblox.nodeSelector.kubernetes.io/hostname`
- `skyforge.infobloxUrl`
- `images.skyforgeServer`
- `images.skyforgeServerWorker`
- `kubernetes.imagePullSecrets`

## Why these differences are allowed

### Auth

Local and OSS use `password` mode.
Prod uses OIDC.

This is a config difference, not a separate code path.

### Gateway addresses

Prod uses concrete gateway addresses.
Local `k3d` uses NodePort pinning and localhost binding, so the address list is intentionally empty in the local overlay.

### Debug logging

Local enables SSO proxy access logs for debugging.
Prod does not need that by default.

### Infoblox

Infoblox is staged locally and depends on KubeVirt plus Multus.
It is not part of the promoted prod base yet, so the local overlay is allowed to turn it on and provide its local wiring.

### Image tags

Local may point at candidate Skyforge server/worker images under test.
The rest of the platform shape should remain the prod-shaped base.

## Non-goals

The local environment must not reintroduce:

- a separate ingress stack such as local NGINX frontdoor
- local-only tool proxy behavior
- local-only API wiring
- different platform feature toggles outside the approved list

## Operational rule

If you need a new local-only override, update both:

- `scripts/check-k3d-parity.py`
- this document

If you cannot justify the override in this document, it probably belongs in the shared base instead.
