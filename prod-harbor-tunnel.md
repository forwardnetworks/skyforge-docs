# Production Harbor Tunnel

The `labpp-sales-prod01` production host may not have direct L3 reachability to
`harbor.local.forwardnetworks.com`. Until that network path is available, image
pulls can use a temporary SSH reverse tunnel from an operator workstation that
can reach both Harbor and the production host.

This is an operational bridge for Harbor pulls only. Do not treat it as the
permanent production registry contract.

## Active Contract

- Production host: `labpp-sales-prod01.dc.forwardnetworks.com`
- Harbor registry: `harbor.local.forwardnetworks.com`
- Tunnel listener on prod: `127.0.0.1:15443`
- Local token proxy on prod: `127.0.0.1:443 -> 127.0.0.1:15443`
- k3s registry mirror endpoint:
  `https://harbor.local.forwardnetworks.com:15443`

The production host maps `harbor.local.forwardnetworks.com` to `127.0.0.1` in
`/etc/hosts` so Harbor TLS SNI and Harbor's auth token realm stay consistent.

## Start Or Refresh The Tunnel

Run this from a workstation that can reach Harbor:

```sh
ssh -fN \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -R 127.0.0.1:15443:harbor.local.forwardnetworks.com:443 \
  arch@labpp-sales-prod01.dc.forwardnetworks.com
```

The prod host also needs the local `skyforge-harbor-443-proxy.service` enabled.
That service forwards Harbor auth token requests from `127.0.0.1:443` to the
SSH tunnel on `127.0.0.1:15443`.

## Validate

On the prod host:

```sh
ss -ltnp | grep -E '127.0.0.1:(443|15443)'
curl -k https://harbor.local.forwardnetworks.com/v2/
sudo crictl pull harbor.local.forwardnetworks.com/forward/fwd_collector:26.4.0-15
```

Expected unauthenticated `curl` response is HTTP `401`. A credentialed Kubernetes
pull should produce a normal `Pulled` event.

## Remove

When direct Harbor routing exists, remove the bridge:

```sh
pkill -f 'ssh .*127.0.0.1:15443:harbor.local.forwardnetworks.com:443' || true
ssh arch@labpp-sales-prod01.dc.forwardnetworks.com '
  sudo systemctl disable --now skyforge-harbor-443-proxy.service || true
  sudo rm -f /etc/systemd/system/skyforge-harbor-443-proxy.service
  sudo rm -f /usr/local/sbin/skyforge-harbor-local-443-proxy.py
  sudo sed -i "/# skyforge temporary harbor ssh tunnel/d" /etc/hosts
  sudo rm -f /etc/rancher/k3s/registries.yaml
  sudo systemctl daemon-reload
  sudo systemctl restart k3s
'
```

