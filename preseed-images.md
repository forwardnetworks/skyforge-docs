# Preseeding Images (Avoiding Docker Hub Rate Limits)

Skyforge labs are created as Kubernetes Pods. If a node has to pull an image that lives on Docker Hub (for example `python:3.13-alpine`) and your cluster is not authenticated to Docker Hub, the pull can fail with a `429 Too Many Requests` rate-limit.

## Current Behavior

- Skyforge’s `netlab` generator sets defaults so `kind: linux` nodes use a Skyforge-hosted image:
  - `ghcr.io/forwardnetworks/skyforge-linux-host:20260127`
- This avoids Docker Hub pulls for Linux endpoints and ensures required tools exist for Forward’s `commandSets: ["UNIX"]` endpoint profile (see below).
- Skyforge’s in-repo Containerlab blueprints also pin Linux nodes to the same image to avoid Docker Hub rate limits.

## Forward `UNIX` Command Set Requirements

In Forward, the `UNIX` CLI endpoint profile runs a small baseline set of commands like:

- `ifconfig`
- `netstat -ln`
- `hostname`
- `uname -a`

`skyforge-linux-host:20260127` includes `net-tools` (for `ifconfig`/`netstat`), and BusyBox provides `hostname`/`uname`.

## If You Still Need Docker Hub Images

Options (pick one):

1) **Authenticate your cluster to Docker Hub** (recommended if you must pull from Docker Hub).
2) **Mirror Docker Hub images into your registry** (recommended for air-gapped/OSS).
3) **Pin all lab images to a non–Docker Hub registry** (Skyforge’s preferred approach).

## Optional: Pre-pull “Hot” Images

If you want to reduce first-run latency, pre-pull the most common images onto every node (method varies by distro/runtime).

For k0s/containerd nodes, prefer `k0s ctr` (it uses the correct socket at `/run/k0s/containerd.sock`).

You can SSH to each node and run the helper script:

```sh
cd skyforge-private
sudo ./scripts/preseed-images.sh --all --helm
```

If you need to pull private images (GHCR), set:

```sh
export SKYFORGE_REGISTRY_AUTH="USERNAME:GHCR_TOKEN"
```

Manual `k0s ctr` example:

```sh
sudo k0s ctr -n k8s.io images pull ghcr.io/forwardnetworks/skyforge-linux-host:20260127
sudo k0s ctr -n k8s.io images pull ghcr.io/forwardnetworks/ceos:4.34.2F
sudo k0s ctr -n k8s.io images pull ghcr.io/forwardnetworks/skyforge-clabernetes-launcher:<tag>
```
