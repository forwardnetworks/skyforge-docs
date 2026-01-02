# PKI / CA integration

Skyforge can issue long-lived TLS certificates for engineers and internal services.
The CA keypair is stored in Kubernetes Secrets and used by the Skyforge server.

## Required secrets

Provide the CA materials as secrets (PEM-encoded):

- `skyforge-pki-ca-cert` (`SKYFORGE_PKI_CA_CERT`)
- `skyforge-pki-ca-key` (`SKYFORGE_PKI_CA_KEY`)
- `skyforge-ssh-ca-key` (`SKYFORGE_SSH_CA_KEY`) for SSH user certificates

The same CA cert should also be stored in `skyforge-ca-cert` so pods can trust it.

## Default TTL

Set `SKYFORGE_PKI_DEFAULT_DAYS` (default `365`).
Set `SKYFORGE_SSH_DEFAULT_DAYS` (default `30`) for SSH certificates.

## Trusting the CA (engineers)

Download the root from the UI or API:

- UI: Dashboard → PKI → “Download root CA”
- API: `GET /api/pki/root`

## SSH user certificates

Skyforge can issue SSH user certificates for jump-host access (for example, Forward Networks device sync).
Download the SSH CA public key and add it to `known_hosts` or the target server’s `TrustedUserCAKeys`.

### Get SSH CA public key

- UI: Dashboard → PKI → “Download SSH CA public key”
- API: `GET /api/pki/ssh/root`

### Issue an SSH certificate

Use the PKI UI to generate a keypair + certificate, then save:

- Private key (keep secure, e.g. `~/.ssh/skyforge_id_rsa`)
- Certificate (save alongside as `~/.ssh/skyforge_id_rsa-cert.pub`)

Example `known_hosts` entry:

```text
@cert-authority *.local.forwardnetworks.com <ssh-ca-public-key>
```

Skyforge uses the authenticated username as the default principal when issuing SSH certs.

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
