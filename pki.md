# PKI / CA integration

Skyforge can issue long-lived TLS certificates for engineers and internal services.
The CA keypair is stored in Kubernetes Secrets and used by the Skyforge server.

## Required secrets

Provide the CA materials as secrets (PEM-encoded):

- `skyforge-pki-ca-cert` (`SKYFORGE_PKI_CA_CERT`)
- `skyforge-pki-ca-key` (`SKYFORGE_PKI_CA_KEY`)

The same CA cert should also be stored in `skyforge-ca-cert` so pods can trust it.

## Default TTL

Set `SKYFORGE_PKI_DEFAULT_DAYS` (default `365`).

## Trusting the CA (engineers)

Download the root from the UI or API:

- UI: Dashboard → PKI → “Download root CA”
- API: `GET /api/pki/root`

### macOS

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain skyforge-root.crt
```

### Ubuntu/Debian

```bash
sudo cp skyforge-root.crt /usr/local/share/ca-certificates/skyforge-root.crt
sudo update-ca-certificates
```

### Kubernetes workloads

Mount the CA cert into your pod and set `SSL_CERT_FILE` to a bundle that includes it.
A common pattern is:

1) Init container builds a bundle from the system CA + Skyforge CA.
2) App container reads the bundle from an `emptyDir`.

See `k8s/overlays/k3s-traefik/patch-ca-trust.yaml` for the pattern used in this repo.

## Traefik (edge TLS)

To use the Skyforge CA for the public hostname:

1) Issue a cert for `skyforge.<domain>` in the PKI UI.
2) Update the `proxy-tls` secret with the new cert + key.
3) Restart Traefik or reapply the ingress resources.
