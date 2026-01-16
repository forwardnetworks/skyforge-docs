# Cilium Migration Notes (k3s)

This doc captures an attempted migration from k3s default networking (flannel + kube-proxy) to Cilium (eBPF, kube-proxy replacement) on the `skyforge-1/2/3` k3s cluster.

## Goal

- Replace flannel with Cilium as the CNI.
- Enable kube-proxy replacement in Cilium.

## What Happened

After installing Cilium, the cluster became unstable for normal pods (CoreDNS, Skyforge workloads). Pods would get stuck in `ContainerCreating` with sandbox/CNI failures. Cilium agents were running, but endpoint creation/regeneration failed.

### Symptoms

- `kubectl describe pod ...` showed errors like:
  - `plugin type="cilium-cni" failed (add): unable to create endpoint: ...`
- `cilium-agent` logs showed repeated eBPF compilation failures:
  - `error: 'CALLS_MAP' macro redefined [-Werror,-Wmacro-redefined]`
  - `error: 'ENABLE_ARP_RESPONDER' macro redefined [-Werror,-Wmacro-redefined]`
  - `error: 'MONITOR_AGGREGATION' macro redefined [-Werror,-Wmacro-redefined]`
  - `Failed to compile bpf_lxc.o` / `Failed to compile bpf_host.o`

Because the datapath programs could not be compiled/loaded, Cilium could not reliably create endpoints for pods, which blocked system services and Skyforge.

## Rollback (Performed)

We rolled back to restore cluster health and get Skyforge running again.

1) Remove Cilium from the cluster:

- `helm -n kube-system uninstall cilium`

2) Restore k3s server config (re-enable defaults):

- On `skyforge-1`, move the Cilium-only config out of the way:
  - `/etc/rancher/k3s/config.yaml` → `/etc/rancher/k3s/config.yaml.cilium_bak.<ts>`

3) Restore flannel CNI config and remove Cilium CNI config on all nodes:

- Remove `05-cilium.conflist` from:
  - `/var/lib/rancher/k3s/agent/etc/cni/net.d/`
  - `/etc/cni/net.d/`
- Restore flannel from the backup file if present:
  - `10-flannel.conflist.cilium_bak` → `10-flannel.conflist`
- Ensure `/etc/cni/net.d/10-flannel.conflist` matches the k3s agent copy.

4) Restart k3s services:

- `systemctl restart k3s` on `skyforge-1`
- `systemctl restart k3s-agent` on `skyforge-2` / `skyforge-3`

After the rollback:
- CoreDNS returned to `Running`.
- Longhorn volumes reattached and workloads recovered.
- Skyforge pods were restarted to clear earlier “object not registered / no relationship found” transient failures from the broken networking period.

## Next Attempt (Suggested)

Before reattempting Cilium:

- Confirm the exact Cilium version + embedded `clang`/toolchain compatibility with our kernel (`6.1.x` Photon OS) and k3s (`v1.33.x`).
- Try a Cilium version known to compile successfully on this kernel/toolchain combination.
- Consider testing in a small throwaway k3s cluster first (single node) to validate eBPF compilation.
- Only enable kube-proxy replacement after basic CNI datapath is stable (CoreDNS + a sample workload).

## Notes

- Longhorn still contains a stale `nodes.longhorn.io/skyforge.local.forwardnetworks.com` object from the pre-rename era. It should be cleaned up via Longhorn’s supported “node removal” workflow once replicas are confirmed safe/migrated.

