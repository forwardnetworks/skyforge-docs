# Kubernetes TLS (Skyforge on k3s)

Skyforge Gateway API references `skyforge/proxy-tls` for TLS termination.

Provision `proxy-tls` directly with your signed certificate and key for the Skyforge hostname.

## Option A: self-signed (dev)
Generate a self-signed cert for your Skyforge hostname:

```bash
HOST=<hostname>
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout certs/skyforge.key \
  -out certs/skyforge.crt \
  -subj "/CN=${HOST}" \
  -addext "subjectAltName=DNS:${HOST}"
```

Then populate `proxy-tls` in `deploy/skyforge-secrets.yaml` and apply via Helm.

## Option B: corporate-signed
Place your signed cert chain + key in:
- `certs/skyforge.crt`
- `certs/skyforge.key`

Then update `proxy-tls` in `deploy/skyforge-secrets.yaml` and apply via Helm.

## Trusting the issuing CA on operator machines

If your Skyforge cert is signed by an internal/corporate CA (for example Forward Root CA), install that root CA into your local trust store or browsers will show "Not secure" even when the cluster cert is correct.

Examples:

- Debian/Ubuntu:
  - copy the root CA PEM to `/usr/local/share/ca-certificates/forward-root-ca.crt`
  - run `sudo update-ca-certificates`
- Arch Linux:
  - copy the root CA PEM to `/etc/ca-certificates/trust-source/anchors/forward-root-ca.crt`
  - run `sudo trust extract-compat`
