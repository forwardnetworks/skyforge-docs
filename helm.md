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

## Recommended: GHCR (OCI) chart storage

To avoid copying chart files to the k3s host, publish the chart to GHCR as an
OCI artifact and install directly from `ghcr.io`.

### Publish (dev machine)

```bash
cd skyforge-private

# Login (uses your existing gh auth)
gh auth refresh -h github.com -s write:packages,read:packages
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin

# Package + push
helm lint charts/skyforge
helm package charts/skyforge -d /tmp
helm push /tmp/skyforge-<chart-version>.tgz oci://ghcr.io/forwardnetworks/charts
```

This pushes to `oci://ghcr.io/forwardnetworks/charts/skyforge` using the chart
`version:` from `charts/skyforge/Chart.yaml`.

### Deploy (k3s host)

Ensure the host has `helm` and `gh` configured, then run:

```bash
# Login (uses your existing gh auth)
gh auth refresh -h github.com -s read:packages
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin

# Install/upgrade
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  --version <chart-version> \
  -f /root/skyforge-values.yaml \
  -f /root/skyforge-secrets.yaml
```

By default this expects these files on the host (not committed):
- `/root/skyforge-values.yaml` (non-secret values)
- `/root/skyforge-secrets.yaml` (secrets)

If the k3s host can clone this repo, you can instead point at the committed
non-secret values file and keep only secrets on-host:

```bash
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  --version <chart-version> \
  -f ./deploy/skyforge-values.yaml \
  -f /root/skyforge-secrets.yaml
```

## Required values

Populate the following before installing:

- `skyforge.hostname` (public hostname for the ingress routes)
- `skyforge.domain` (email suffix for default users)
- `secrets.items.*` entries for passwords, TLS certs, and Git credentials
- LDAP secrets only if you enable LDAP-backed auth for Skyforge/NetBox/Nautobot/MinIO
- If you use EVE-NG / Netlab integrations: `secrets.items.eve-runner-ssh-key`, `secrets.items.netlab-runner-rsa`, and the server pool secrets (`secrets.items.skyforge-eve-servers`, `secrets.items.skyforge-netlab-servers`). The server pool values accept either a JSON array or `{"servers":[...]}`; see `deploy/skyforge-secrets.example.yaml`.

Use `--set-file` for large values (TLS, SSH keys):

```bash
helm upgrade --install skyforge ./charts/skyforge -n skyforge \
  --set-file secrets.items.proxy-tls.tls\.crt=certs/tls.crt \
  --set-file secrets.items.proxy-tls.tls\.key=certs/tls.key
```

## Images

Override any container image in `values.yaml` under the `images` map (for
example, to point at a private registry).
