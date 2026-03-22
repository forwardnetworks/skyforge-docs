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
  --dst-image ghcr.io/<org>/cisco-iol-kne:17.16.01a \
  --iol-cmd "/opt/iol/bin/iol --type l3" \
  --startup-target /opt/iol/startup-config \
  --console-port 5000 \
  --push
```

For IOL-L2, use the same script with a layer-2 command line:

```bash
./scripts/build-kne-cisco-iol-image.sh \
  --base-image ghcr.io/<org>/cisco-ioll2-base:17.16.01a \
  --dst-image ghcr.io/<org>/cisco-ioll2-kne:17.16.01a \
  --iol-cmd "/opt/iol/bin/iol --type l2" \
  --startup-target /opt/iol/startup-config \
  --console-port 5000 \
  --push
```

## Runtime contract

The generated image entrypoint does the following:

1. Copies KNE mounted startup file (`/startup.cfg`) into your requested startup path.
2. Starts `sshd` (best effort) when available.
3. Launches your `--iol-cmd` process as PID 1.
4. Exposes port `22` and the configured console port.

## KNE / netlab expectations

1. KNE model should be canonical `iol` or `ioll2`.
2. `Config.Image` must be set (no KNE hardcoded default image for IOL).
3. If your image uses a non-default console port, set `IOL_CONSOLE_PORT` in node env.
