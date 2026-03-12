# Infoblox Runtime Notes

- Multus is not installed in the local k3d cluster, so only the pod-network management NIC is live-tested here.
- Infoblox KubeVirt management NIC contract uses `managementInterfaceModel` and `auxiliaryInterfaceModel`.
- Local k3d now pins the management NIC to `virtio` with `podNetworkBinding: bridge` so the appliance sees a more direct management interface during licensing/bootstrap.
- The lifecycle autostop path must ignore the VM while `license_pending=true`; otherwise the VM can be halted during bootstrap and the licensing workflow never converges.
- Live March 12 finding: a single-NIC local boot still fails even with `virtio + bridge`. Guest console shows:
  - `Configure Public Interface for Licensing`
  - `Error code: 255 from Configure Public Interface for Licensing`
  - later `LAN port IPv4 192.168.1.2 ... Fatal error during Infoblox startup`
- Practical conclusion: local Infoblox likely needs a true multi-NIC shape, with a dedicated management NIC first and auxiliary NICs present, not just a single pod-network interface.
