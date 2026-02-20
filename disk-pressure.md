# Disk Pressure Recovery (k0s nodes)

If Skyforge shows `task-workers: down` (or Kubernetes pods fail to start), check for root disk exhaustion on the cluster nodes.

## Symptoms

- `kubectl describe pod ...` shows sandbox errors like:
  - `mkdir /var/log/pods/...: no space left on device`
- Node conditions show `DiskPressure=True`
- Large `/var/log/syslog` and/or very large `/var/log/pods/*/*.log`

## Verify

On each node:

```bash
df -h /
sudo du -sh /var/log/* | sort -h | tail
```

## Expand the root filesystem (VM disk already resized)

On each node:

```bash
sudo sgdisk -e /dev/sda || true
sudo growpart /dev/sda 1
sudo resize2fs /dev/sda1
df -h /
```

## Ensure `/var/log` is on the root disk

If `/var/log` was temporarily moved elsewhere, move it back:

```bash
sudo systemctl stop rsyslog || true
sudo systemctl stop syslog.socket || true

sudo mkdir -p /var/log-root
sudo rsync -aHAX --delete /var/log/ /var/log-root/ || true

sudo sed -i.bak "/\\/var\\/lib\\/k0s\\/var-log \\/var\\/log none bind/d" /etc/fstab

sudo umount /var/log || sudo umount -l /var/log
sudo rm -rf /var/log.old || true
sudo mv /var/log /var/log.old || true
sudo mv /var/log-root /var/log

sudo systemctl start syslog.socket || true
sudo systemctl start rsyslog || true

df -h / /var/log
```

## Add guardrails (journald + logrotate)

On each node:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/skyforge.conf >/dev/null <<'EOF'
[Journal]
SystemMaxUse=1G
SystemMaxFileSize=100M
SystemKeepFree=2G
EOF
sudo systemctl restart systemd-journald
```

Make `rsyslog` logs rotate quickly (size-based):

```bash
sudo sed -i -E 's/^\\s*weekly\\s*$/\\tdaily/; s/^\\s*rotate\\s+[0-9]+\\s*$/\\trotate 14/' /etc/logrotate.d/rsyslog
if ! sudo rg -q '^\\s*size\\s+' /etc/logrotate.d/rsyslog; then
  sudo sed -i -E '0,/^\\{/{s/^\\{/{\\n\\tsize 100M/}' /etc/logrotate.d/rsyslog
fi
```

Run logrotate hourly (so size triggers are checked frequently):

```bash
sudo mkdir -p /etc/systemd/system/logrotate.timer.d
sudo tee /etc/systemd/system/logrotate.timer.d/override.conf >/dev/null <<'EOF'
[Timer]
OnCalendar=
OnCalendar=hourly
RandomizedDelaySec=5m
EOF
sudo systemctl daemon-reload
sudo systemctl restart logrotate.timer
```

## Verify recovery

```bash
kubectl -n skyforge get pods | rg 'skyforge-worker|user-scope-sync'
kubectl describe node skyforge-1 | rg 'DiskPressure|Ready'
kubectl describe node skyforge-2 | rg 'DiskPressure|Ready'
kubectl describe node skyforge-3 | rg 'DiskPressure|Ready'
```
