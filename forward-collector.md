# Forward Collector (Workspace Option)

Use this flow when a workspace needs its own Forward collector. Skyforge creates the collector through the Forward API (SaaS or on-prem) and returns an authorization key you can run on a host you control. Once it appears in Forward, select it in the workspace settings.

## Create the Collector

1) Save Forward credentials in the workspace settings (SaaS or on-prem base URL).
2) Click **Add collector** → **Create collector**.
3) Copy the authorization key and run command shown in the dialog.

## Build the Collector Image (One-Time)

1) Obtain the Forward collector installer (`fwd-unix-<version>.sh`) from Forward Networks. Keep it out of git.
2) Use the standalone guide as a build context (example path below):

```bash
cd /Users/captainpacket/Projects/active/skyforge/collector-standalone
```

3) Update `fwd.properties.template` if you are using Forward on-prem (the URL must match the base URL in the workspace settings):

```
url = https://your-forward-appliance
```

4) Build and push the image to GHCR:

```bash
TAG=20260102-collector
IMAGE=ghcr.io/forwardnetworks/skyforge-forward-collector:${TAG}
docker buildx build --platform linux/amd64 -t "${IMAGE}" --push .
```

## Run the Collector

Use the command shown in the Skyforge workspace dialog, for example:

```bash
docker run --rm \
  -e TOKEN="<forward-username>:<forward-password>" \
  -e PROXY_HOST= \
  -e PROXY_PORT= \
  -e PROXY_USERNAME= \
  -e PROXY_PASSWORD= \
  ghcr.io/forwardnetworks/skyforge-forward-collector:latest
```

## Select in Skyforge

After the collector registers in Forward, open the workspace Forward settings, refresh the collector list, and select the new collector.

## Cleanup

Stop the container when the workspace no longer needs the collector. Remove any test collector instances from Forward to avoid confusion.
