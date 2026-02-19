# Helm

Skyforge ships a full Helm chart under `components/charts/skyforge`. The chart renders the
same manifests as the kustomize flow, with value-based substitution for
hostnames, images, and defaults.

## Quickstart

```bash
helm upgrade --install skyforge ./components/charts/skyforge \
  -n skyforge --create-namespace \
  -f values.yaml
```

## OSS baseline (recommended)

Use pre-created Kubernetes secrets and keep Helm in reference-only mode:

```bash
helm upgrade --install skyforge ./components/charts/skyforge \
  -n skyforge --create-namespace \
  --set secrets.create=false \
  -f values.yaml
```

This keeps runtime secrets out of Helm release values/history.

For production/stable environments, keep this invariant on every upgrade:

- `secrets.create=false`
- `secrets.validatePrecreated=true`
- `--reset-values` with your tracked values files

Avoid `--reuse-values` for production upgrades. Reusing historical values can
silently restore older embedded TLS data (`proxy-tls`) and revert certificates.

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
helm lint components/charts/skyforge
helm package components/charts/skyforge -d /tmp
helm push /tmp/skyforge-<chart-version>.tgz oci://ghcr.io/forwardnetworks/charts
```

This pushes to `oci://ghcr.io/forwardnetworks/charts/skyforge` using the chart
`version:` from `components/charts/skyforge/Chart.yaml`.

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
- `skyforge.gateway.addresses` (recommended for Cilium Gateway API node-IP ingress; example `[{type: IPAddress, value: "10.128.16.60"}]`)
- `skyforge.dex.authMode` and provider values (for Google mode: `skyforge.dex.google.clientID` + pre-created `dex-google-client-secret`)
- If `secrets.create=false` (recommended): pre-create required Kubernetes
  Secrets (for example `proxy-tls`, `skyforge-session-secret`,
  `skyforge-admin-shared`, database/object-storage/Dex secrets).
- If `secrets.create=true` (local/dev compatibility): provide `secrets.items.*`
  values for passwords, TLS certs, and credentials from a local untracked file.
- LDAP secrets only if you enable LDAP-backed auth for Skyforge/NetBox/Nautobot
- If you use EVE-NG / Netlab integrations: `secrets.items.eve-runner-ssh-key`, `secrets.items.netlab-runner-rsa`, and the server pool secrets (`secrets.items.skyforge-eve-servers`, `secrets.items.skyforge-netlab-servers`). The server pool values accept either a JSON array or `{"servers":[...]}`; see `deploy/skyforge-secrets.example.yaml`.

Use `--set-file` for large values (TLS, SSH keys):

```bash
helm upgrade --install skyforge ./components/charts/skyforge -n skyforge \
  --set-file secrets.items.proxy-tls.tls\.crt=certs/tls.crt \
  --set-file secrets.items.proxy-tls.tls\.key=certs/tls.key
```

If your TLS cert is signed by the Forward CA, install the Forward Root CA in your workstation trust store so browsers mark `https://skyforge.local.forwardnetworks.com` as secure.

When rotating TLS certs with `secrets.create=false`, update the in-cluster
secret directly (Helm should not own `proxy-tls`):

```bash
kubectl -n skyforge create secret tls proxy-tls \
  --cert=/path/to/skyforge.fullchain.pem \
  --key=/path/to/skyforge.key \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Images

Override any container image in `values.yaml` under the `images` map (for
example, to point at a private registry).
