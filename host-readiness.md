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

## 4. Skyforge Netlab API Setup

Skyforge communicates with the host via a lightweight Python API.

### Installation

1.  **Deploy API Code:**
    Copy `netlab/api/netlab_api.py` from the Skyforge repository to the host (e.g., `/opt/skyforge/netlab-api/netlab_api.py`).

2.  **Python Environment:**
    Create a venv for the API (or reuse the netlab one, but isolation is better).
    ```bash
    sudo mkdir -p /opt/skyforge/netlab-api
    sudo python3 -m venv /opt/skyforge/netlab-api/venv
    
    # Install API dependencies
    sudo /opt/skyforge/netlab-api/venv/bin/pip install fastapi uvicorn pydantic
    ```

### Service Configuration (Systemd)

Create a systemd unit file at `/etc/systemd/system/netlab-api.service`.

**Important:** The API process runs as `root` to allow spawning privileged subprocesses, but it drops privileges to `NETLAB_RUN_AS_USER` for standard operations.

```ini
[Unit]
Description=Skyforge Netlab API
After=network.target docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/skyforge/netlab-api

# Configuration
Environment="NETLAB_RUN_AS_USER=skyforge"
Environment="NETLAB_API_DATA_DIR=/var/lib/skyforge/netlab-api"
Environment="NETLAB_SOURCE=/opt/netlab/netlab-src"
Environment="NETLAB_ANSIBLE_PATH=/opt/netlab/venv/bin"
Environment="PYTHONPATH=/opt/netlab/netlab-src"

# Command
ExecStart=/opt/skyforge/netlab-api/venv/bin/python /opt/skyforge/netlab-api/netlab_api.py --bind 0.0.0.0 --port 8090

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Enable and Start:**
```bash
sudo mkdir -p /var/lib/skyforge/netlab-api
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

- **Root-owned artifacts:** If you see `root`-owned files in user workspaces (`~/netlab/...`), ensure `NETLAB_RUN_AS_USER` is correctly set in the systemd unit and that the `netlab_api.py` is the latest version from the Skyforge repo.
\
