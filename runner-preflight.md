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

If user workdirs under `/home/<user>/netlab/...` contain root-owned artifacts (commonly `netlab.lock` and `clab-*`), the Netlab API is likely spawning Netlab as `root`.

- Update the Netlab API script on the runner from `netlab/api/netlab_api.py` in this repo (it drops privileges for the Netlab subprocess when running as root and then reconciles workdir ownership back to the user).
- Restart the service:

```bash
systemctl cat netlab-api.service
sudo systemctl restart netlab-api.service
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

## LabPP: Telnet EOF hotfix

If LabPP `START` runs fail with an error like:

```
Range [0, 0 + -1) out of bounds for length 4096
```

it typically means the embedded Telnet expect client crashed when the remote console closed the connection (EOF during `read()`).

Skyforge keeps the fix in `fwd/test/labpp/src/main/java/com/forwardnetworks/tools/labdevicesetup/TelnetExpectClient.java`. After updating/building that class, rebuild and redeploy the skyforge-server image so the LabPP CLI picks it up from the bundled `fwd` repo.
