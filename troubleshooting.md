# Troubleshooting

## API base path confusion
Skyforge’s external API is served behind Cilium Gateway API routes under:
- `https://<hostname>/api/skyforge/*`

If you try `https://<hostname>/auth/login` it will 404; the correct path is:
- `https://<hostname>/api/skyforge/auth/login`

## Swagger “Try it out” hits localhost or wrong base URL
The deployed OpenAPI schema must include a `servers` entry with:
- `url: /api/skyforge`

Check:
```bash
curl -sk https://<hostname>/openapi.json | head
```

## LDAP (StartTLS) issues
Symptoms:
- LDAP login intermittently fails.
- NetBox/Nautobot login loops or rejects credentials.

Notes:
- StartTLS with python-ldap can require setting global TLS options (not only per-connection options).
- If you use `skipTlsVerify`, ensure both NetBox and Nautobot LDAP configs set the global options consistently.

## Hoppscotch failures
### Helm upgrade failures due to immutable Jobs
If a Helm upgrade fails trying to patch a `Job`, it’s usually because the `spec.template` is immutable.

This chart runs Jobs as Helm hooks to avoid that (they are deleted/recreated automatically).

### Yaade data missing
Cause: the `yaade-data` PVC is missing or was reset.

Fix:
- Ensure the `yaade-data` PVC exists and is bound.
- Restart the `yaade` deployment after restoring data.

## Gitea `/api/v1` is expected
Skyforge uses Gitea’s versioned REST API under:
- `http://gitea:3000/api/v1`

Do not attempt to “remove v1” from Gitea URLs.

## Encore docker build hangs locally
Symptom:
- `encore build docker --push` appears to stall indefinitely with no progress.

Cause:
- Running `encore build docker` directly from `components/server` (a submodule with a `.git` indirection file) can trigger an Encore workspace-root resolution loop.

Required fix path:
- Do not run raw `encore build docker` for Skyforge server images.
- Use the canonical script only:

```bash
./scripts/build-push-skyforge-server.sh --tag <tag>
```

Notes:
- The script enforces standalone mirror builds and dedicated daemon isolation.
- This is the supported local build path for deterministic results.

## Prevent stale UI/image deploy drift
Symptom:
- A deploy "succeeds" but the UI still reflects older routes/pages.

Guardrails:
- `scripts/deploy-skyforge-prod-safe.sh` now requires explicit image refs by default:
  - `SKYFORGE_SERVER_IMAGE=<repo>:<tag>`
  - `SKYFORGE_SERVER_WORKER_IMAGE=<repo>:<tag>-worker`
- The deploy script hard-fails if:
  - worker tag is not `<server-tag>-worker`,
  - the deployed image refs do not match requested refs,
  - the live `/assets/skyforge/*` entrypoint hash does not match the running server pod.

Recommended production flow:
```bash
./scripts/build-push-skyforge-server.sh --tag <tag>

SKYFORGE_SERVER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:<tag> \
SKYFORGE_SERVER_WORKER_IMAGE=ghcr.io/forwardnetworks/skyforge-server:<tag>-worker \
./scripts/deploy-skyforge-prod-safe.sh
```
