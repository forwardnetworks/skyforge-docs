# Infoblox Runtime Notes

- Infoblox KubeVirt management NIC contract uses `managementInterfaceModel` and `auxiliaryInterfaceModel`.
- Local k3d should run Infoblox in a real multi-NIC shape:
  - management NIC first on the pod network
  - auxiliary NICs present through Multus NADs
  - management NIC pinned to `virtio` with `podNetworkBinding: bridge`
- The lifecycle autostop path must ignore the VM while `license_pending=true`; otherwise the VM can be halted during bootstrap and the licensing workflow never converges.
- Live March 12 finding: a single-NIC local boot still fails even with `virtio + bridge`. Guest console shows:
  - `Configure Public Interface for Licensing`
  - `Error code: 255 from Configure Public Interface for Licensing`
  - later `LAN port IPv4 192.168.1.2 ... Fatal error during Infoblox startup`
- Practical conclusion: local Infoblox needs a true multi-NIC shape, with a dedicated management NIC first and auxiliary NICs present. Do not reconcile the VM back to single-NIC mode.
