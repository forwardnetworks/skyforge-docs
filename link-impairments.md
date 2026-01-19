# Link Impairments (Netem)

Skyforge can apply basic link impairments (latency/jitter, packet loss, and bandwidth limits) to clabernetes-backed
deployments without requiring any tooling inside the network OS containers.

## UI

On the deployment topology graph:

1. Right-click a **link**
2. Choose **Configure impairment…** (or **Clear impairment**)

## How it works

- Skyforge reads the resolved topology (from containerlab/clabernetes artifacts) including link endpoint interface names.
- For each side of the link, Skyforge resolves the clabernetes node pod and executes `tc` in a **non-NOS container**
  (prefers a container name containing `launcher`).
- The impairment is applied to the link interface inside the pod network namespace (`tc qdisc … dev <if>`).

This applies impairment "outside" the NOS while still affecting the actual dataplane traffic for that link.

## Requirements

- The launcher/sidecar container image must include `tc` (iproute2).
- The launcher/sidecar container must have the required privileges (typically `CAP_NET_ADMIN`) to set qdiscs.

If either requirement is missing, the API call returns per-node errors in the response.

## API

Endpoint:

- `POST /api/workspaces/:id/deployments/:deploymentID/links/impair`

Example request:

```json
{
  "edgeId": "e-3",
  "action": "set",
  "delayMs": 50,
  "jitterMs": 10,
  "lossPct": 1.0,
  "rateKbps": 100000
}
```

To clear:

```json
{
  "edgeId": "e-3",
  "action": "clear"
}
```

