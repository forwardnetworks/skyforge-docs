# Netlab (BYOS runner)

Skyforge can run Netlab against a user-provided Netlab host by calling the upstream `netlab api` server over HTTPS.

## Runner requirements

- Netlab installed on the BYOS host.
- Netlab API server running (recommended as a systemd service).
- Optional: HTTP Basic Auth and TLS termination.

## Upstream Netlab API

Netlab ships an API server:

```text
netlab api [--bind <addr>] [--port <port>] [--auth-user <user>] [--auth-password <password>]
          [--tls-cert <path>] [--tls-key <path>]
```

Endpoints (from upstream docs):

- `GET /healthz` – health check
- `GET /templates?dir=<path>` – list YAML templates in a directory
- `POST /jobs` – start a job (`action`, `workdir`, `workspaceRoot`, `topologyPath`, `topologyUrl`, `cleanup`)
- `GET /jobs/{id}` – job details
- `GET /jobs/{id}/log` – job log output
- `POST /jobs/{id}/cancel` – cancel queued job
- `GET /status` – `netlab status --all` output

## Template delivery model

Skyforge does not install Netlab templates onto BYOS hosts. Netlab API jobs run in a working directory on the BYOS host:

- If you want to run a complex template that includes extra files (custom configs, `check.config`, etc), pre-stage it on the BYOS host and point the run at that directory (`workdir`).
- For simple/self-contained labs, you can use `topologyUrl` to fetch a `topology.yml` from an HTTP(S) URL, but Netlab will not automatically fetch an entire template directory tree.

## Netlab defaults on the runner

Use Netlab’s system defaults (for example `/etc/netlab/defaults.yml`) to pin common images without editing every topology.

See https://netlab.tools/defaults/ for options.
