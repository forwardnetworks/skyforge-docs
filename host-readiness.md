# Skyforge Host Readiness Guide

This guide details the requirements and configuration steps to prepare a compute host (bare metal or VM) for orchestration via Skyforge. These hosts will run network simulations using [Netlab](https://netlab.tools/) and [Containerlab](https://containerlab.dev/).

## 1. System Requirements

### Hardware
- **CPU:** Multi-core processor recommended.
- **RAM:** Sufficient memory for the intended lab topologies (e.g., 16GB+ for small labs, 64GB+ for complex multi-vendor labs).
- **Disk:** SSD recommended for image storage and IO performance.
- **Virtualization:**
  - If running on **Bare Metal**: VT-x/AMD-V enabled in BIOS.
  - If running as a **VM**: **Nested Virtualization** must be enabled to run VM-based network nodes (e.g., vEOS, IOSv).

### Operating System
- **Linux:** Ubuntu 22.04 LTS or Debian 11/12 recommended.
- **Kernel:** Recent kernel supported by Docker and Containerlab.

## 2. Core Dependencies

### Docker
Install the latest Docker Engine.
```bash
# Example for Ubuntu
curl -fsSL https://get.docker.com | sh
```

### Containerlab
Install Containerlab.
```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
```

### Python 3
Ensure Python 3.9+ is installed along with `pip` and `venv`.
```bash
sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv python3-dev build-essential
```

### Netlab
Skyforge currently recommends installing Netlab from source to ensure compatibility with recent templates.

1.  **Clone Netlab:**
    ```bash
    sudo mkdir -p /opt/netlab
    sudo git clone https://github.com/ipspace/netlab.git /opt/netlab/netlab-src
    ```

2.  **Install Dependencies:**
    It is recommended to use a virtual environment for Netlab.
    ```bash
    sudo python3 -m venv /opt/netlab/venv
    sudo /opt/netlab/venv/bin/pip install --upgrade pip
    sudo /opt/netlab/venv/bin/pip install -r /opt/netlab/netlab-src/requirements.txt
    sudo /opt/netlab/venv/bin/pip install paramiko  # Required for Ansible operations
    ```

3.  **Link Netlab:**
    Add `/opt/netlab/netlab-src` to `PYTHONPATH` or install in editable mode if preferred, but the API wrapper handles `NETLAB_SOURCE`.

## 3. User & Permissions

The Skyforge agent runs via the Netlab API, which requires specific permissions to manage network namespaces and containers.

1.  **Create the Service User (Optional but Recommended):**
    You can use an existing user (e.g., `ubuntu`) or create a dedicated one.
    ```bash
    sudo useradd -m -s /bin/bash skyforge
    ```

2.  **Docker Group:**
    Add the user to the `docker` group.
    ```bash
    sudo usermod -aG docker skyforge
    ```

3.  **Sudo & Capabilities:**
    Netlab requires privileged access for certain operations (`ip netns`, `containerlab deploy`). Configure passwordless sudo for these commands.

    Create `/etc/sudoers.d/skyforge-clab`:
    ```sudoers
    # Allow skyforge user to run containerlab and ip commands without password
    # REPLACE 'skyforge' with your actual username if different
    skyforge ALL=(root) NOPASSWD: SETENV: /usr/bin/containerlab, /usr/sbin/ip
    ```
    *Note: `SETENV` is crucial for passing environment variables.*

## 4. Netlab API Setup (BYOS host)

Skyforge communicates with the BYOS Netlab host via the upstream Netlab API server (`netlab api`).

### Service Configuration (Systemd)

Create a systemd unit file at `/etc/systemd/system/netlab-api.service`.

Recommended: run the service as the same user that owns the Netlab workdir tree (to avoid root-owned artifacts).

```ini
[Unit]
Description=Netlab API
After=network.target docker.service

[Service]
Type=simple
User=skyforge
WorkingDirectory=/home/skyforge

# Optional: store logs in a stable location
Environment="NETLAB_API_DATA_DIR=/var/lib/skyforge/netlab-api"

# Optional: Basic Auth
Environment="NETLAB_API_USER=skyforge"
Environment="NETLAB_API_PASSWORD=change-me"

ExecStart=/usr/bin/netlab api --bind 0.0.0.0 --port 8090

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo mkdir -p /var/lib/skyforge/netlab-api
sudo chown -R skyforge:skyforge /var/lib/skyforge/netlab-api
sudo systemctl daemon-reload
sudo systemctl enable --now netlab-api
```

## 5. Security & Networking

### Firewall
- Allow traffic on **TCP 8090** (or your configured port) from the Skyforge Runner.
- **Recommended:** Use a reverse proxy (Nginx/Apache) with TLS on port 443 to forward requests to localhost:8090, as the API itself does not handle SSL/TLS.

### SSH Access
- Ensure the Skyforge Runner can SSH to the host (if using direct runner mode) or that the API is accessible.

## 6. Validation

Run the following commands on the host to verify readiness:

1.  **Check Versions:**
    ```bash
    docker version
    containerlab version
    /opt/netlab/venv/bin/netlab version
    ```

2.  **Verify Sudo Permissions:**
    Run as the target user (`skyforge`):
    ```bash
    sudo -u skyforge bash -lc 'sudo -n -E containerlab version'
    sudo -u skyforge bash -lc 'sudo -n ip netns list'
    ```
    *These should return output without asking for a password.*

3.  **Check API Health:**
    ```bash
    curl http://localhost:8090/healthz
    # Should return: {"status":"ok"}
    ```

## 7. Troubleshooting

- **Root-owned artifacts:** If you see `root`-owned files in user workspaces (`~/netlab/...`), ensure the Netlab API service is not running as `root` (and that users have passwordless sudo for the required binaries).
\
