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

Ensure the host has `helm` and `gh` configured, then run from your local machine:

```bash
# Login (uses your existing gh auth)
gh auth refresh -h github.com -s read:packages
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin

# Copy local values/secrets to the host (use /tmp, then delete).
scp ./deploy/skyforge-values.yaml ./deploy/skyforge-secrets.yaml skyforge.local.forwardnetworks.com:/tmp/

# Install/upgrade from the host
ssh skyforge.local.forwardnetworks.com "helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  --reset-values \
  --version <chart-version> \
  -f /tmp/skyforge-values.yaml \
  -f /tmp/skyforge-secrets.yaml"

ssh skyforge.local.forwardnetworks.com "rm -f /tmp/skyforge-values.yaml /tmp/skyforge-secrets.yaml"
```

Keep host file footprint minimal: use `/tmp` and remove after the deploy.

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
