# wlanpi-persistent-identity

Prevents "host identification changed" SSH warnings and maintains stable machine-id for systemd services across A/B partition switches.

## How it works

This package uses bind mounts to make persistent copies of identity files appear in their expected system locations.

On first boot, the service:

1. Generates machine-id and SSH host keys if they don't exist
2. Copies these files to `/home/.persistent-identity/`
3. Bind mounts the persistent copies over the system locations
4. On subsequent boots or partition switches, restores from persistent storage

If installed after first boot, existing identity files are saved to persistent storage.

**Important:** Persistent storage always takes precedence. If identity files exist in both locations, the persistent version overwrites the local version to maintain consistency across partitions.

This ensures SSH host keys and machine-id remain constant across A/B partition switches, while allowing each partition's other configurations to differ.

### What gets persisted

This package persists only system identity - five specific files and nothing else.

The package persists these files to `/home/.persistent-identity/`:

- `/etc/ssh/ssh_host_ecdsa_key` and `.pub`
- `/etc/ssh/ssh_host_ed25519_key` and `.pub`
- `/etc/machine-id`

**Note:** RSA keys are not managed by this utility as they are deprecated in modern SSH.

### What are bind mounts?

A bind mount makes a file or directory from one location appear at another location.

Example: bind mount persistent SSH key over system location

```bash
mount --bind /home/.persistent-identity/etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
```

Now `/etc/ssh/ssh_host_rsa_key` shows the contents of `/home/.persistent-identity/etc/ssh/ssh_host_rsa_key`. Any changes to either path affect the same underlying file.

### Why bind mounts?

For WLAN Pi's A/B partition system, bind mounts provide:

- Simplicity: Direct file replacement with no layering complexity.
- Explicit behavior: What you see is exactly what's in persistent storage.
- Independence: Each partition's configs remain separate, only identity files are shared by this package.
- Performance and low overhead: Bind mounts have lower overhead than overlays because they're a simple VFS redirection rather than a union filesystem with merge logic and copy-on-write operations.
- Standard practice: Bind mounts are commonly used for individual file persistence in A/B partition systems.

## Service ordering

The service runs very early in the boot process:

- Before `systemd-journald.service` to ensure machine-id exists before logging starts
- Before `ssh.service` to ensure host keys are available when SSH starts
- After `local-fs.target` to ensure /home is mounted

## Verification

Service status:

```bash
systemctl status wlanpi-persistent-identity.service
```

Bind mounts:

```bash
mount | grep /etc
```

Check persistent storage:

```bash
ls -la /home/.persistent-identity/etc/ssh/
cat /home/.persistent-identity/etc/machine-id
```

View logs:

```bash
# System journal
journalctl -u wlanpi-persistent-identity.service

# Persistent log file
cat /var/log/wlanpi-persistent-identity.log
```

## Troubleshooting

### Service fails to start

Is `/home` mounted?

```bash
mountpoint /home
```

### SSH host key warnings after partition switch

Probably means bind mounts didn't work.

```bash
# Are bind mounts active?
mount | grep /etc/ssh

# Does persistent storage exist?
ls -la /home/.persistent-identity/etc/ssh/

# Service status and logs
systemctl status wlanpi-persistent-identity.service
journalctl -u wlanpi-persistent-identity.service -b
```

### Bind mounts present but wrong keys

Maybe the persistent storage has different keys than expected.

```bash
# Compare fingerprints
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf /home/.persistent-identity/etc/ssh/ssh_host_ed25519_key.pub
```

### Checking what files are bind mounted

```bash
findmnt --list | grep /etc
```