# Cilium performance notes (Skyforge dev)

Skyforge runs VM-heavy workloads (vrnetlab/QEMU, IOL, etc.). Cilium is configured to optimize for:

- Low datapath overhead (kube-proxy replacement + eBPF)
- High connection churn (collector↔devices, websockets, UI)
- High throughput (artifact downloads, large CLI outputs)

## Files

- `deploy/cilium-values.before.yaml`: captured `helm -n kube-system get values cilium --all` before performance tuning.
- `deploy/cilium-values.yaml`: performance + k3s CNI-path overlay applied on top of the existing Cilium release.
- `deploy/cilium-values-dualstack.yaml`: IPv6 dual-stack overlay (ULA IPv6) for pods/services.
- `deploy/cilium-values-netkit-migrate.yaml`: **one-time** helper overlay when switching veth → netkit.

## Current tuning (overlay)

- `routingMode: native` + `autoDirectNodeRoutes: true`
  - Nodes are L2-adjacent, so we avoid VXLAN tunnel overhead.
- `ipv4NativeRoutingCIDR: 100.70.0.0/16`
  - Matches the cluster-pool Pod CIDR on this cluster.
- `cni.confPath: /var/lib/rancher/k3s/agent/etc/cni/net.d`
  - k3s uses this directory for its active CNI config. If Cilium writes to `/etc/cni/net.d` you can accidentally fall
    back to flannel (symptom: pods get `10.42.x.x` IPs and cross-node networking breaks).
- `socketLB.enabled: true`
  - Reduce service load balancing overhead.
- `enableIPv4BIGTCP: true`
  - Improve throughput/CPU efficiency on modern kernels.
- `l2NeighDiscovery.enabled: true`
  - Improves ARP stability; with IPv6 enabled, this also helps NDP.
- `bpf.datapathMode: netkit`
  - Uses the netkit datapath (kernel ≥ 6.7) for lower overhead than veth.

## Apply / rollback

Apply:

```sh
export KUBECONFIG=skyforge-private/.kubeconfig-skyforge
helm -n kube-system upgrade --install cilium cilium/cilium --version 1.19.0-rc.1 \
  -f skyforge-private/deploy/cilium-values.before.yaml \
  -f skyforge-private/deploy/cilium-values.yaml \
  -f skyforge-private/deploy/cilium-values-dualstack.yaml \
  --wait --timeout 15m
```

Rollback (use the captured baseline values):

```sh
export KUBECONFIG=skyforge-private/.kubeconfig-skyforge
helm -n kube-system upgrade --install cilium cilium/cilium -f skyforge-private/deploy/cilium-values.before.yaml --wait --timeout 10m
```

## Netkit migration (one-time)

When switching `bpf.datapathMode` from `veth` → `netkit`, Cilium may refuse to start if it detects restored endpoint
state created under the legacy datapath.

Use the **one-time** migration overlay:

```sh
export KUBECONFIG=skyforge-private/.kubeconfig-skyforge
helm -n kube-system upgrade --install cilium cilium/cilium --version 1.19.0-rc.1 \
  -f skyforge-private/deploy/cilium-values.before.yaml \
  -f skyforge-private/deploy/cilium-values.yaml \
  -f skyforge-private/deploy/cilium-values-dualstack.yaml \
  -f skyforge-private/deploy/cilium-values-netkit-migrate.yaml \
  --wait --timeout 15m
```

Then immediately re-run the normal upgrade **without** `cilium-values-netkit-migrate.yaml` so future restarts don’t wipe
state.

## IPv6 dual-stack (ULA)

This dev cluster uses **ULA IPv6** for “real” dual-stack pods/services (not just link-local):

- Pod CIDR (IPv6): `fd00::/104` (Cilium cluster-pool)
- Service CIDR (IPv6): `fd00:64::/112` (k3s `--service-cidr`)

Node interfaces are configured with IPv4 + IPv6 InternalIPs (example):

```text
skyforge-1: 10.128.16.58  fd00:128:16::58
skyforge-2: 10.128.16.54  fd00:128:16::54
skyforge-3: 10.128.16.55  fd00:128:16::55
```

### Verifying pod/service dual-stack

Pods should receive a non-link-local IPv6 from `fd00::/104`:

```sh
kubectl -n default run dscheck --image=ghcr.io/nicolaka/netshoot:latest --restart=Never -- sleep 3600
kubectl -n default wait pod/dscheck --for=condition=Ready --timeout=120s
kubectl -n default exec dscheck -- ip -br a
kubectl -n default delete pod dscheck
```

Services are still single-stack by default, but support dual-stack with `ipFamilyPolicy: PreferDualStack`:

```sh
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dscheck
  namespace: default
spec:
  selector:
    app: dscheck
  ports:
  - name: http
    port: 80
    targetPort: 80
  ipFamilyPolicy: PreferDualStack
YAML
kubectl -n default get svc dscheck -o jsonpath='{.spec.clusterIPs} {.spec.ipFamilies} {.spec.ipFamilyPolicy}{"\n"}'
kubectl -n default delete svc dscheck
```

## Gateway API (Traefik disabled, no external LB)

We disable k3s `traefik` and `servicelb` and rely on **Cilium Gateway API + hostNetwork**:

- `cilium-envoy` runs as a DaemonSet in `kube-system` with `hostNetwork: true`.
- Envoy listens on `0.0.0.0:80` / `0.0.0.0:443` (and `[::]:80` / `[::]:443`) on **every node**, which supports
  round-robin DNS without an external LoadBalancer.

### Notes on `Gateway` status in hostNetwork mode

When using Cilium Gateway API in *hostNetwork* mode, you may see:

- `kubectl -n skyforge get gateway skyforge` shows `PROGRAMMED=False`
- `Reason=AddressNotAssigned`

This is a Cilium Gateway API status/reporting limitation: the data plane can be working even when the controller does
not publish an “address” in `Gateway.status.addresses`.

### How to validate ingress works (round-robin DNS)

From inside the cluster, validate each node answers HTTP and HTTPS by forcing DNS resolution to the node IP (important
for HTTPS because clients need SNI):

```sh
for ip in 10.128.16.58 10.128.16.54 10.128.16.55; do
  echo "== $ip"
  curl -s -o /dev/null -w "%{http_code} %{time_total}\n" \
    http://$ip/status -H "Host: skyforge.local.forwardnetworks.com" || true

  curl -k -s -o /dev/null -w "%{http_code} %{time_total}\n" \
    --resolve skyforge.local.forwardnetworks.com:443:$ip \
    https://skyforge.local.forwardnetworks.com/status || true
done
```

If you hit `https://<node-ip>` directly, some clients may not send SNI and the connection can be reset by Envoy.
Always test HTTPS with the hostname (or `--resolve`).

If you see errors like `TLSRouteList not registered`, install Gateway API experimental CRDs (TLSRoute/TCPRoute/etc):

```sh
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/experimental-install.yaml
```

## “No iptables” note

We aim to minimize iptables usage:

- `--disable-kube-proxy` in k3s + `kubeProxyReplacement: true` in Cilium moves Service load-balancing into eBPF.
- `bpf.masquerade: true` uses eBPF for SNAT where supported.

Some iptables/nftables rules may still exist on the host for non-Cilium components; don’t interpret their presence as
“kube-proxy is back”.
