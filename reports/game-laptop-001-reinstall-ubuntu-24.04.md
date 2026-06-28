# Report: game-laptop-001 reinstall Ubuntu 24.04

Date: 2026-06-28
Machine: Lenovo Legion R9000P / Windows 11
Executor: game laptop Codex

## Summary

Completed the requested reinstall from the accidental Ubuntu 26.04 WSL distribution to explicit Ubuntu 24.04 LTS.

- Removed old WSL distribution: `Ubuntu`
- Installed new WSL distribution: `Ubuntu-24.04`
- WSL install path: `D:\WSL\Ubuntu`
- WSL version: `2`
- Default Linux user: `jiaxi`
- Installed Ubuntu version: `Ubuntu 24.04.4 LTS (Noble Numbat)`
- Python version: `Python 3.12.3`
- Git version: `git version 2.43.0`

No Docker, CUDA Toolkit, PyTorch, Tailscale, Linux NVIDIA driver, Windows firewall change, or Windows boot-flow change was performed.

## User Confirmation

User explicitly confirmed that the existing WSL Ubuntu instance contained no data to preserve and agreed to delete it:

> 确认删除当前 WSL Ubuntu，里面没有需要保留的数据，同意用管理员脚本重装 Ubuntu-24.04 到 D:\WSL\Ubuntu

## Actions Performed

1. Cloned and read the collaboration repository.
2. Read:
   - `README.md`
   - `docs/status.md`
   - `tasks/game-laptop-001-reinstall-ubuntu-24.04.md`
3. Created an admin helper script for this task:
   - `scripts/game-laptop-001-reinstall-ubuntu-24.04.ps1`
   - `scripts/run-game-laptop-001-admin.cmd`
4. Ran the admin helper manually via elevated Windows shell.
5. Terminated and unregistered the previous `Ubuntu` WSL distribution.
6. Removed only the old target directory `D:\WSL\Ubuntu`.
7. Installed explicit distribution:

```powershell
wsl --install -d Ubuntu-24.04 --location D:\WSL\Ubuntu
```

8. Created Linux user `jiaxi` during first launch.
9. Installed base packages:

```bash
build-essential curl wget git openssh-server ca-certificates gnupg lsb-release tmux htop python3 python3-venv python3-pip nvtop
```

10. Enabled systemd in `/etc/wsl.conf`.
11. Enabled and started SSH service.
12. Verified GPU visibility through WSL-provided NVIDIA integration.

## Important Network Note

During package installation, apt initially stalled and later reported DNS failures resolving `archive.ubuntu.com`.

Observed `/etc/resolv.conf` before fix:

```text
nameserver 10.255.255.254
search ctc
```

Fix applied inside WSL only:

```ini
[network]
generateResolvConf=false
```

Current `/etc/resolv.conf`:

```text
nameserver 1.1.1.1
nameserver 8.8.8.8
```

After this change and `wsl --shutdown`, apt package installation completed.

This did not change Windows firewall, Windows boot flow, Clash settings, or host networking.

## Verification

### WSL

```text
NAME            STATE    VERSION
Ubuntu-24.04    Stopped  2
```

Registry path check:

```text
DistributionName : Ubuntu-24.04
BasePath         : D:\WSL\Ubuntu
Version          : 2
DefaultUid       : 1000
```

### Ubuntu

```text
PRETTY_NAME="Ubuntu 24.04.4 LTS"
VERSION_ID="24.04"
VERSION="24.04.4 LTS (Noble Numbat)"
VERSION_CODENAME=noble
```

### User

```text
whoami -> jiaxi
```

### Python and Git

```text
Python 3.12.3
git version 2.43.0
```

### systemd and SSH

```text
systemctl is-system-running -> running
ssh.service -> enabled, active (running)
sshd listens on 0.0.0.0:22 and [::]:22 inside WSL
```

### GPU / CUDA Driver Interface

```text
NVIDIA GeForce RTX 4060 Laptop GPU
Driver Version: 566.26
CUDA Version shown by nvidia-smi: 12.7
```

WSL CUDA shim libraries:

```text
/usr/lib/wsl/lib/libcuda.so
/usr/lib/wsl/lib/libcuda.so.1
/usr/lib/wsl/lib/libcuda.so.1.1
```

No Linux NVIDIA driver or CUDA Toolkit package was installed.

### IPs

```text
WSL IP: 172.28.122.115
Windows host IP from WSL: 172.28.112.1
```

## Issues / Warnings

- WSL prints a warning that localhost proxy settings were detected but not mirrored into WSL NAT mode. This is expected for the current Clash setup and was not modified in this task.
- GitHub and apt networking may depend on DNS/proxy conditions. The task required only Ubuntu 24.04 reinstall and base verification; Clash proxy configuration is left for a later task.
- `wsl --update` had previously returned `Wsl/UpdatePackage/0x80190193` / `403`, but current WSL itself is usable and Ubuntu-24.04 installed successfully.

## Not Performed

- Docker installation
- CUDA Toolkit installation
- PyTorch installation
- Tailscale installation/configuration
- Linux NVIDIA driver installation
- Windows firewall changes
- Windows boot-flow changes
- Clash configuration changes

## Recommendation for Next Task

Next task should configure WSL proxy access via the repository-approved approach, preferably Windows `netsh interface portproxy` for Clash/Mihomo rather than enabling Clash `allow-lan`, as described in `README.md`.
