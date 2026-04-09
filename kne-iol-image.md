# Build A KNE-Native Cisco IOL Image (No vrnetlab)

This path assumes you already have a vendor-provided Cisco IOL base image
containing the proprietary runtime binaries.

Skyforge/KNE does not build or ship Cisco binaries.

## Build wrapper image

Use the helper script to produce a KNE-compatible runtime image:

```bash
cd /home/captainpacket/src/skyforge
./scripts/build-kne-cisco-iol-image.sh \
  --base-image ghcr.io/<org>/cisco-iol-base:17.16.01a \
  --dst-image ghcr.io/<org>/kne/cisco_iol:17.16.01a-kne-r1 \
  --iol-cmd '/iol/iol.bin "$IOL_PID" -e "$IOL_NUM_SLOTS_EFFECTIVE" -s 0 -c "$IOL_CONFIG_PATH" -n 1024' \
  --startup-target /iol/config.txt \
  --console-port 5000 \
  --push
```

For IOL-L2, use the same script with a layer-2 command line:

```bash
./scripts/build-kne-cisco-iol-image.sh \
  --base-image ghcr.io/<org>/kne/cisco_iol:17.16.01a-kne-r27 \
  --dst-image ghcr.io/<org>/kne/cisco_iol_l2:17.16.01a-kne-r2 \
  --iol-cmd '/iol/iol.bin "$IOL_PID" -e "$IOL_NUM_SLOTS_EFFECTIVE" -s 0 -c "$IOL_CONFIG_PATH" -n 1024' \
  --replace-iol-binary ~/x86_64_crb_linux_l2-adventerprisek9-ms.iol \
  --startup-target /iol/config.txt \
  --console-port 5000 \
  --push
```

## Runtime contract

The generated image entrypoint does the following:

1. Copies KNE mounted startup file (`/startup.cfg`) into your requested startup path.
2. Copies that same startup file into the runtime config path consumed by the IOL process (`/iol/config.txt` by default).
3. Ensures `/iol/.iourc` and `/iol/NETMAP` exist before launching the Cisco IOL process.
4. Starts `sshd` on port `22`.
5. Bridges SSH logins into the IOL console on `127.0.0.1:<console-port>`.
6. Auto-answers the IOS first-boot `initial configuration dialog` prompt so SSH command execution reaches the normal CLI prompt.
7. Launches your `--iol-cmd` process as PID 1.
8. Disables NIC offloads on `eth*` interfaces before starting IOL.

This means external automation sees an IOS CLI over SSH on port `22`, while the
image still uses the native local IOL console internally.

## KNE / netlab expectations

1. KNE model should be canonical `iol` or `ioll2`.
2. `Config.Image` must be set (no KNE hardcoded default image for IOL).
3. If your image uses a non-default console port, set `IOL_CONSOLE_PORT` in node env.
4. If your base image already ships a real `.iourc` or `NETMAP`, the wrapper leaves those in place; otherwise it creates empty placeholders so the binary can boot.

## Base image requirements

The helper script currently assumes a Debian/apt-based base image and installs:

- `openssh-server`
- `inetutils-telnet`
- `procps`
- `ethtool`

The base image must still provide the proprietary Cisco IOL binary itself. For
the current Forward image layout, that binary is `/iol/iol.bin`.
