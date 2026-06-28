# Task: Reinstall WSL Ubuntu 24.04

请在游戏本 Codex 上执行本任务。

当前情况：

- 已安装 Ubuntu 到 `D:\WSL\Ubuntu`。
- 但当前发行版是 Ubuntu 26.04 LTS，Python 是 3.14.4。
- 目标工作负载是 Python/PyTorch/CUDA 轻量训练。

决策：

- 不保留 Ubuntu 26.04。
- 改为明确安装 Ubuntu 24.04 LTS。
- 原因：Ubuntu 26.04 和 Python 3.14 对 PyTorch/深度学习生态太超前，包兼容性风险高。

边界：

- 不安装 Docker。
- 不安装 CUDA Toolkit。
- 不安装 PyTorch。
- 不安装 Tailscale。
- 不安装 Linux NVIDIA driver。
- 不改 Windows 防火墙。
- 不改 Windows 启动流程。
- 不删除 `D:\WSL` 以外的任何内容。

执行前必须先确认：

1. 当前 Ubuntu 里没有用户需要保留的数据。
2. 用户明确同意删除当前 WSL Ubuntu 发行版。
3. PowerShell/Codex 当前是管理员权限。

如果任一条件不满足，请停止并报告。

## 建议步骤

在 Windows PowerShell 中检查：

```powershell
wsl --list --verbose
wsl --status
wsl --list --online
```

如果用户确认当前 Ubuntu 可删除，注销当前发行版：

```powershell
wsl --terminate Ubuntu
wsl --unregister Ubuntu
```

清理旧安装目录：

- 只处理 `D:\WSL\Ubuntu`。
- 如果 `D:\WSL\Ubuntu` 仍存在，先列出内容并确认它确实是旧 WSL 安装目录，再删除。
- 不要删除 `D:\WSL` 本身的其他目录。

安装明确版本：

```powershell
wsl --install -d Ubuntu-24.04 --location D:\WSL\Ubuntu
```

如果 `--location` 或 `Ubuntu-24.04` 不可用，停止并报告完整错误，不要自行换方案。

启动 Ubuntu-24.04，创建用户：

- 用户名：`jiaxi`
- 密码：让用户自己输入，不要记录。

在 Ubuntu 内执行基础配置：

```bash
sudo apt update
sudo apt install -y build-essential curl wget git openssh-server ca-certificates gnupg lsb-release tmux htop python3 python3-venv python3-pip
sudo apt install -y nvtop || true
```

启用 systemd，确保 `/etc/wsl.conf` 包含：

```ini
[boot]
systemd=true
```

然后在 Windows PowerShell 执行：

```powershell
wsl --shutdown
```

重新进入 Ubuntu-24.04 后启用 SSH：

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

## 验证

报告以下输出：

```powershell
wsl --list --verbose
```

```bash
cat /etc/os-release
python3 --version
git --version
systemctl is-system-running
systemctl status ssh --no-pager
nvidia-smi
ls -l /usr/lib/wsl/lib/libcuda.so*
hostname -I
ip route | awk '/default/ {print $3}'
```

## 结果提交

把结果写入：

```text
reports/game-laptop-001-reinstall-ubuntu-24.04.md
```

不要继续进入代理、Tailscale、PyTorch 阶段。

