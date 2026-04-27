# Management Access

Skyforge management access lets local tools reach KNE-backed lab nodes without
publishing every device port outside the cluster.

## V1 Contract

- Scope is per deployment and per node.
- Transport is standard OpenSSH `ProxyJump` through the Skyforge management SSH
  endpoint.
- Users authenticate to the Skyforge jump endpoint with either their saved
  Skyforge SSH public key or their Skyforge API token as the jump-host password.
- The only supported target port is SSH/TCP `22`.
- Skyforge does not publish every lab device externally; the jump endpoint
  validates access, then dials the selected node's in-cluster KNE Service.

This keeps the public attack surface to one SSH listener while still supporting
VS Code, Claude, Ansible, and direct `ssh` workflows without a custom client
install.

## Prod External Port Contract

Prod Cato VPN access permits only one external SSH listener on TCP `22`.
`skyforge-fwd.dc.forwardnetworks.com:22` is therefore reserved for deployment
management access. Gitea remains available over HTTPS under `/git`; Git over SSH
must stay disabled or move to a different allowed VIP.

If a deployment tries to enable both Gitea SSH and management SSH on the same
external port and shared VIP, the Helm chart fails before rollout.

## UI Workflow

Open **Settings** and save **Your SSH public key** in the **SSH Keys** card.
This is the user's workstation public key and is also the key they should use
for their Gitea account SSH access. Skyforge keeps the generated deploy key
separate because its private half is used only by Skyforge automation when
cloning SSH template repos.

Open a deployment and select **Management**. The page shows:

- current KNE namespace and topology name
- node management metadata from the captured topology artifact
- a direct `ssh -J` command
- a complete `~/.ssh/config` snippet
- Ansible `ansible_ssh_common_args`
- the active jump host and generated target host pattern

Click **Verify** to re-read the deployment runtime contract and confirm the
management endpoint metadata is still available.

## CLI Workflow

Use standard OpenSSH. The generated hostnames are not DNS records; Skyforge reads
the target from the SSH `direct-tcpip` request after `ProxyJump` authentication.

```sshconfig
Host *.<deployment-id>.<user-scope>.skyforge.access
  User admin
  ProxyJump <skyforge-username>@skyforge-fwd.dc.forwardnetworks.com
```

Then connect to a lab node:

```bash
ssh -J <skyforge-username>@skyforge-fwd.dc.forwardnetworks.com admin@<node>.<deployment-id>.<user-scope>.skyforge.access
```

When prompted for the jump-host password, use a Skyforge API token if no
personal SSH public key is saved. Target node credentials remain the device
credentials from the lab image/template.

## WebSocket Fallback

The older `skyforge-access` WebSocket bridge remains in the API as a fallback
for development and controlled troubleshooting, but it is not the primary prod
workflow and should not be required for SE laptops.

## Why Not One Bastion Per User

A user-scoped bastion would need additional authorization routing for every
deployment, lifecycle cleanup for idle sessions, and per-user namespace reach
into labs owned by different user scopes. That expands both the trust boundary
and the cleanup surface.

The v1 SSH jump endpoint is narrower: it validates the Skyforge user, checks
access to the requested deployment, resolves the node through the KNE runtime
identity already used by terminal/browser features, then dials only the node's
in-cluster management Service.

## Why Not One Bastion Per Deployment

A deployment-scoped bastion is a reasonable future option if workflows need
multi-protocol services beyond SSH. It should still remain private to the
cluster and be reached through the same Skyforge-authenticated entry point.

For SSH automation, a single Skyforge-authenticated `direct-tcpip` jump service
is lighter than creating and reconciling a separate pod per deployment.

## Forward Host Visibility Note

Forward inferred hosts are not created just because a Skyforge endpoint or
container exists. Forward's host computation requires edge-port MAC evidence and
non-empty subnet/IP evidence. If a Skyforge-modeled host is collected as a device
or connected through a non-edge topology link, it can appear in ARP/MAC evidence
without materializing as an inferred host.

When validating host visibility:

1. Confirm the host MAC is present in switch MAC tables.
2. Confirm the host IP is joined through ARP evidence.
3. Confirm the switch port is treated as a Forward edge port.
4. Confirm the computed host has at least one subnet/IP association.

If those conditions are not true, fix the lab traffic/edge-port evidence in
Skyforge or the template before changing Forward source code.
