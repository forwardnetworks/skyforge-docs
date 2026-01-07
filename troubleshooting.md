# Troubleshooting

## API base path confusion
Skyforge’s external API is served behind Traefik under:
- `https://<hostname>/api/skyforge/*`

If you try `https://<hostname>/auth/login` it will 404; the correct path is:
- `https://<hostname>/api/skyforge/auth/login`

## Swagger “Try it out” hits localhost or wrong base URL
The deployed OpenAPI schema must include a `servers` entry with:
- `url: /api/skyforge`

Check:
```bash
curl -sk https://<hostname>/swagger/openapi.json | head
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
