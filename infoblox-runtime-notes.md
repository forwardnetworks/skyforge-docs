# Infoblox Runtime Notes

- Infoblox KubeVirt management NIC contract uses `managementInterfaceModel` and `auxiliaryInterfaceModel`.
- Skyforge should run Infoblox in a real multi-NIC shape:
  - management NIC first on the pod network
  - auxiliary NICs present through Multus NADs
  - explicit MAC addresses on all interfaces (default/lan1/ha/lan2) to avoid KubeVirt libvirt XML failures
  - LAN1 should prefer DHCP IPAM (`skyforge.infoblox.vm.multus.lan1.ipamType=dhcp`) where available for resilient addressing across VM restarts
  - HA/LAN2 can stay `host-local` unless you have DHCP on those segments
- Multus must remain the primary CNI config when meshnet is present.
  - If `00-meshnet.conflist` is ordered before `00-multus.conf`, NAD attachments are ignored and VMI sync fails with
    `pod link ... is missing`.
  - Enforce `kube-multus-ds` arg `--multus-master-cni-file-name=05-cilium.conflist` to prevent recursive
    `00-meshnet.conflist` generation (`multus -> multus -> ...`) after daemonset restarts.
- Cilium must not run in exclusive CNI mode when meshnet is expected to attach
  data-plane links.
  - Set `kube-system/cilium-config` `cni-exclusive: "false"`.
  - If Cilium previously renamed `00-meshnet.conflist` to
    `00-meshnet.conflist.cilium_bak`, restore the active file before restarting
    the `meshnet` DaemonSet.
- The lifecycle autostop path must ignore the VM while `license_pending=true`; otherwise the VM can be halted during bootstrap and the licensing workflow never converges.
- The temp-license bootstrap must hold the serial console open long enough to observe a real `login:`/prompt before sending commands; piping a fixed input blob and closing stdin too early will falsely mark bootstrap as failed.
- Lifecycle cronjobs (`*-vm-autostop`, `*-vm-reseed`, `*-vm-license`) are expected to stay unsuspended by default.
  - Chart values now expose explicit `suspend` booleans under each lifecycle lane and default them to `false`.
  - Treat `suspend=true` as a temporary operator action only.
- License reconcile health gate:
  - Only HTTP readiness codes `2xx`, `3xx`, `401`, `403` are considered healthy.
  - `000`, `5xx`, and other non-ready codes keep reconcile active so first-boot and post-reseed bootstrap does not silently stall.
- Live March 15 finding: KubeVirt + Multus plumbing is healthy, but appliance init still fails in-image during runonce. Guest console shows:
  - `Configure Public Interface for Licensing`
  - `Error code: 255 from Configure Public Interface for Licensing`
  - later `LAN port IPv4 192.168.1.2 ... Fatal error during Infoblox startup`
- Practical conclusion: do not reconcile back to single-NIC mode. Keep multi-NIC + explicit MAC contract, and treat remaining failure as Infoblox image/day0 bootstrap contract work (not Kubernetes network plumbing).
