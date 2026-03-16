# Infoblox Runtime Notes

- Infoblox KubeVirt management NIC contract uses `managementInterfaceModel` and `auxiliaryInterfaceModel`.
- Skyforge should run Infoblox in a real multi-NIC shape:
  - management NIC first on the pod network
  - auxiliary NICs present through Multus NADs
  - explicit MAC addresses on all interfaces (default/lan1/ha/lan2) to avoid KubeVirt libvirt XML failures
- Multus must remain the primary CNI config when meshnet is present.
  - If `00-meshnet.conflist` is ordered before `00-multus.conf`, NAD attachments are ignored and VMI sync fails with
    `pod link ... is missing`.
- The lifecycle autostop path must ignore the VM while `license_pending=true`; otherwise the VM can be halted during bootstrap and the licensing workflow never converges.
- Live March 15 finding: KubeVirt + Multus plumbing is healthy, but appliance init still fails in-image during runonce. Guest console shows:
  - `Configure Public Interface for Licensing`
  - `Error code: 255 from Configure Public Interface for Licensing`
  - later `LAN port IPv4 192.168.1.2 ... Fatal error during Infoblox startup`
- Practical conclusion: do not reconcile back to single-NIC mode. Keep multi-NIC + explicit MAC contract, and treat remaining failure as Infoblox image/day0 bootstrap contract work (not Kubernetes network plumbing).
