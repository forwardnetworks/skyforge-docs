# Kubernetes TLS (Skyforge on k3s)

Skyforge’s Traefik IngressRoutes reference `skyforge/proxy-tls` for TLS termination.

If you enable the PKI integration, you can issue a leaf cert for the Skyforge hostname from the PKI UI and replace the `proxy-tls` secret with the signed cert + key. Keep the CA root in `skyforge-ca-cert` so pods can trust it.

## Option A: self-signed (recommended for dev)
Generate a self-signed cert for your Skyforge hostname and store it in `./certs/`:

```bash
HOST=<hostname>
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout certs/skyforge.key \
  -out certs/skyforge.crt \
  -subj "/CN=${HOST}" \
  -addext "subjectAltName=DNS:${HOST}"
```

Then apply the secrets overlay:
```bash
kubectl apply -k k8s/overlays/k3s-traefik-secrets
```

## Option B: corporate-signed (your internal CA)
Use the CSR flow in `docs/sign.txt`, then place the cert + key under `./certs/`:

- `certs/skyforge.crt` (leaf + intermediate chain)
- `certs/skyforge.key`

Then apply the secrets overlay:
```bash
kubectl apply -k k8s/overlays/k3s-traefik-secrets
```
