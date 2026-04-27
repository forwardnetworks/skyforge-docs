# Management Access

Skyforge management access lets local tools reach KNE-backed lab nodes without
publishing every device port outside the cluster.

## V1 Contract

- Scope is per deployment and per node.
- Authentication is Skyforge API authentication; local automation should set
  `SKYFORGE_API_TOKEN`.
- Transport is an authenticated WebSocket TCP bridge from Skyforge to the
  in-cluster KNE node Service.
- The only supported target port is SSH/TCP `22`.
- No public NodePort, LoadBalancer, or long-lived external bastion is created.

This keeps the public attack surface small while still supporting VS Code,
Claude, Ansible, and direct SSH workflows through `ProxyCommand`.

## UI Workflow

Open a deployment and select **Management**. The page shows:

- current KNE namespace and topology name
- node management metadata from the captured topology artifact
- a reusable SSH `ProxyCommand`
- a complete `~/.ssh/config` snippet
- Ansible `ansible_ssh_common_args`
- direct tunnel command for smoke testing

Click **Verify** to re-read the deployment runtime contract and confirm the
management endpoint metadata is still available.

## CLI Workflow

Use the helper as an SSH `ProxyCommand`:

```sshconfig
Host skyforge-my-lab-*
  HostName %h
  User admin
  ProxyCommand skyforge-access tunnel --base-url https://skyforge.dc.forwardnetworks.com --user <user-scope> --deployment <deployment-id> --node %h --port %p
```

For repo-local testing without installing a binary:

```bash
export SKYFORGE_API_TOKEN='<api-token>'
./scripts/skyforge-access-tunnel \
  --base-url https://skyforge.dc.forwardnetworks.com \
  --user <user-scope> \
  --deployment <deployment-id> \
  --node <node> \
  --port 22
```

## Why Not One Bastion Per User

A user-scoped bastion would need additional authorization routing for every
deployment, lifecycle cleanup for idle sessions, and per-user namespace reach
into labs owned by different user scopes. That expands both the trust boundary
and the cleanup surface.

The v1 bridge is narrower: it validates the Skyforge session or API token,
checks access to the requested deployment, resolves the node through the KNE
runtime identity already used by terminal/browser features, then dials only the
node's in-cluster management Service.

## Why Not One Bastion Per Deployment

A deployment-scoped bastion is a reasonable future option if workflows need
rsync, Git, or long-lived multi-protocol sessions. It should still remain
private to the cluster and be reached through the same Skyforge-authenticated
entry point.

For SSH automation, a server-side WebSocket TCP bridge is lighter than creating
and reconciling a separate pod per deployment.

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
