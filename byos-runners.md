# BYOS runners (Netlab/Containerlab) — API + SSH only

This document captures the desired “bring your own server” (BYOS) model for Netlab and Containerlab runners.

## Goal

Make BYOS servers as easy to operate as possible by **minimizing dependencies**:

- Prefer **native Netlab API** and **native Containerlab API** (HTTP/S).
- Use **SSH only for file sync** (templates/artifacts), not for “remote execution plumbing”.
- Avoid requiring Skyforge-specific binaries on the BYOS host.

## High-level model

BYOS workflow is API-first and should avoid extra host-side services/scripts:

1) **HTTPS API** (required)
   - Netlab: talk to the Netlab API endpoint (auth required).
   - Containerlab: talk to the Containerlab API endpoint (auth required).

2) **Git-based templates (preferred)**
   - Netlab/containerlab can launch from a git repo; Skyforge should pass:
     - repo URL (internal/private Gitea URL or public URL)
     - branch/ref
     - template subdir / topology filename
   - Users manage git auth using their normal workflow (e.g. SSH key added to Gitea, or their own git credentials for external repos).

The BYOS host should not need:
- Kubernetes access
- Skyforge runner images
- a Skyforge-specific API wrapper service

## Reality check: Netlab vs Containerlab template fetching

- **Containerlab API server** supports `topologySourceUrl` and can pull from git/raw URLs directly.
- **Netlab API server** (as documented upstream) supports `topologyUrl`, but does not clone a whole repo or fetch a template directory. If your topology depends on adjacent files (Jinja templates, config fragments, plugins), the BYOS host must already have those files in the working directory.

In practice, that means Netlab BYOS needs one of:
- a pre-synced local working directory on the BYOS host (recommended), or
- a future enhancement that stages template directories from git (outside the upstream netlab API scope).

## Workspace configuration

In workspace settings, BYOS is enabled per provider:

- Netlab BYOS
  - `api_url` (e.g. `https://netlab.local.forwardnetworks.com`)
  - `api_auth` (token or user/pass)
  - `ssh_host` (optional; can be same host as `api_url`)
  - `ssh_user` + auth method (SSH key preferred; password fallback)
  - `work_root` (e.g. `/home/<user>/netlab/<workspace>/`)

- Containerlab BYOS
  - `api_url` + auth
  - `ssh_host` (optional)
  - `work_root`

Credential storage should match existing patterns (like EVE credentials): encrypted-at-rest, scoped to the workspace, never logged.

## Template delivery

Preferred: **git clone/pull on the BYOS host**, driven by the native APIs/commands:

- Skyforge passes repo/ref/path; the BYOS tool is responsible for obtaining the files.
- Skyforge should support both:
  - internal/private repo URLs (Gitea)
  - public URLs (e.g., exposed via a Cloudflare tunnel when needed)

Fallback (only if required by the provider API):
- Send a tarball/blob of the template contents over the API request.

## Execution semantics (API)

BYOS execution should use the server’s API endpoints:

- Create:
  - validate API connectivity
  - call the provider “create/prepare” action (Netlab: `create`) using git-based template refs

- Start:
  - call the provider “up/deploy” action (Netlab: `up`; Containerlab: `deploy`) using the same git-based template refs

- Stop/Destroy:
  - call provider “down/destroy” action
  - (optional) cleanup any remote workdir created by the provider (best-effort)

## Observability

BYOS runs should still produce consistent Skyforge run logs:

- Always capture and stream provider logs back (API logs when available; otherwise SSH pull of a logfile).
- Show a clear “sync vs run” breakdown in Skyforge runs.

## Why this design

- Keeps the BYOS server “vanilla”: users can run Netlab/Containerlab the way they normally do.
- Avoids coupling BYOS to Skyforge Kubernetes implementation details.
- Makes it easier to support “remote” BYOS hosts (no cluster connectivity required).
