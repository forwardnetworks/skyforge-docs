# Runner preflight (EVE hosts)

These checks validate the external EVE-NG hosts are ready for Netlab/LabPP runs.

## What should be consistent across hosts
- `netlab` installed (same version)
- `containerlab` installed (same version)
- `apache2` (or equivalent) running to front internal APIs on 443
- `netlab-api.service`, `labpp-api.service`, and `containerlab-api.service` running (if used)
- LDAP shell auth configured (if Skyforge expects user-scoped paths like `/home/{user}/...`)

## Quick commands (run on each EVE host)
```bash
netlab version
containerlab version
systemctl is-active apache2.service netlab-api.service labpp-api.service containerlab-api.service
```

If any of these fail, fix host parity before running E2E so the failures don’t happen late in the workflow.

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

## LabPP API: Telnet EOF hotfix

If LabPP `START` runs fail with an error like:

```
Range [0, 0 + -1) out of bounds for length 4096
```

it typically means the embedded Telnet expect client crashed when the remote console closed the connection (EOF during `read()`).

Skyforge keeps the fix in `fwd/test/labpp/src/main/java/com/forwardnetworks/tools/labdevicesetup/TelnetExpectClient.java`. After updating/building that class, you can replace the class inside the LabPP API jar on each EVE host:

1) Build the class locally:

```bash
cd fwd
./gradlew :test:labpp:classes
```

2) Copy `TelnetExpectClient.class` to each EVE host and update the jar:

```bash
# from your workstation
scp fwd/test/labpp/build/classes/java/main/com/forwardnetworks/tools/labdevicesetup/TelnetExpectClient.class \
  root@<eve-host>:/tmp/TelnetExpectClient.class

# on the EVE host
sudo mkdir -p /tmp/skyforge-labpp-hotfix/com/forwardnetworks/tools/labdevicesetup
sudo mv /tmp/TelnetExpectClient.class /tmp/skyforge-labpp-hotfix/com/forwardnetworks/tools/labdevicesetup/
sudo cp -n /opt/skyforge/labpp-api/labpp-api.jar /opt/skyforge/labpp-api/labpp-api.jar.bak-hotfix-$(date +%Y%m%d-%H%M%S)
sudo zip -q -u /opt/skyforge/labpp-api/labpp-api.jar com/forwardnetworks/tools/labdevicesetup/TelnetExpectClient.class
sudo systemctl restart labpp-api.service
```
