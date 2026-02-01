# Runner preflight (EVE hosts)

These checks validate the external EVE-NG hosts are ready for Netlab/LabPP runs.

## What should be consistent across hosts
- `netlab` installed (same version)
- `containerlab` installed (same version)
- `apache2` (or equivalent) running to front internal APIs on 443
- `netlab-api.service` and `containerlab-api.service` running (if used)
- LDAP shell auth configured (if Skyforge expects user-scoped paths like `/home/{user}/...`)

## Quick commands (run on each EVE host)
```bash
netlab version
containerlab version
systemctl is-active apache2.service netlab-api.service containerlab-api.service
```

If any of these fail, fix host parity before running E2E so the failures don’t happen late in the workflow.

## Fix root-owned Netlab workspace artifacts

If user workdirs under `/home/<user>/netlab/...` contain root-owned artifacts (commonly `netlab.lock` and `clab-*`), Netlab is likely running under `root` (or via `sudo`) and writing into the user tree.

Recommended approach:

- Run the upstream Netlab API (`netlab api ...`) under the same user that owns the lab workspace directory.
- Ensure users have the required sudoers entries (see below) so Netlab does not require an interactive password prompt.

```bash
systemctl cat netlab-api.service
sudo systemctl restart netlab-api.service
```

## Netlab sudo + groups (required)

Netlab invokes privileged operations even when Skyforge runs the Netlab subprocess as the target user:

- `containerlab deploy/destroy` is invoked via `sudo -E containerlab ...`
- `netlab initial` uses `sudo ip netns exec ...` to run initial config scripts inside container namespaces

On the runner host, each lab user must:

- Be in the `docker` group (Docker API access without `sudo`)
- Be in the `clab_admins` group and have passwordless sudo for the required binaries (with `SETENV` to allow `sudo -E`)

Recommended sudoers rule:

- File: `/etc/sudoers.d/skyforge-clab`
- Contents:
  - `%clab_admins ALL=(root) NOPASSWD: SETENV: /usr/bin/containerlab, /usr/sbin/ip`

Validate:

```bash
sudo -u <user> bash -lc 'sudo -n -E containerlab version'
sudo -u <user> bash -lc 'sudo -n ip netns list'
```

## Netlab upgrade (latest commits)

Netlab 26.01 introduces breaking template changes. Until a 26.01 package is published, install from git on each runner:

```bash
/opt/pipx/venvs/networklab/bin/python -m pip install --upgrade git+https://github.com/ipspace/netlab.git
netlab version
```

Note: the version string may still display `25.12.3` even when the commit is newer.

## Netlab Ansible dependencies

Netlab uses Ansible to push initial configs. Ensure `paramiko` is installed in both the Netlab runtime venv and the Skyforge netlab-api venv:

```bash
/opt/netlab/venv/bin/python -m pip install --upgrade paramiko
/opt/skyforge/netlab-api/venv/bin/python -m pip install --upgrade paramiko
```
