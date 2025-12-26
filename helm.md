# Helm

Skyforge ships a full Helm chart under `charts/skyforge`. The chart renders the
same manifests as the kustomize flow, with value-based substitution for
hostnames, images, and defaults.

## Quickstart

```bash
helm upgrade --install skyforge ./charts/skyforge \
  -n skyforge --create-namespace \
  -f values.yaml
```

## Required values

Populate the following before installing:

- `skyforge.hostname` (public hostname for the ingress routes)
- `skyforge.domain` (email suffix for default users)
- `secrets.items.*` entries for passwords, TLS certs, and Git/Semaphore credentials
- LDAP secrets only if you enable LDAP-backed auth for Skyforge/NetBox/Nautobot/MinIO

Use `--set-file` for large values (TLS, SSH keys):

```bash
helm upgrade --install skyforge ./charts/skyforge -n skyforge \
  --set-file secrets.items.proxy-tls.tls\.crt=certs/tls.crt \
  --set-file secrets.items.proxy-tls.tls\.key=certs/tls.key
```

## Images

Override any container image in `values.yaml` under the `images` map (for
example, to point at a private registry).
