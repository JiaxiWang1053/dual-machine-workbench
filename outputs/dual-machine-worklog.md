# 双机工作环境搭建记录

## 目标架构

- MacBook Air 作为主控工作站：开发、浏览、文件整理、Git、Codex。
- 联想拯救者 R9000P 保持 Windows 娱乐优先，在 Windows 内使用 WSL2 Ubuntu 作为 Linux 工作节点。
- Mac 通过 SSH/Tailscale 连接 WSL，运行 Codex、VS Code Remote SSH、Jupyter、tmux 和轻量 PyTorch/CUDA 训练。
- 代码和文档优先放在 Mac 并通过 Git 管理；训练数据和缓存可放在游戏本 WSL 的 D 盘空间内。

## 已知状态

### Mac

- macOS 26.4，arm64。
- OpenSSH 可用：OpenSSH_10.2p1。
- Git 可用：Apple Git 2.50.1。
- Homebrew 未发现。
- Tailscale CLI 未发现。
- 初始检查时 `~/.ssh` 不存在，现已创建。
- Clash Verge/Mihomo 正在监听 `127.0.0.1:7897`。
- macOS 系统代理当前未启用。
- 已生成 Mac 主控专用 SSH key：
  `~/.ssh/id_ed25519_codex_dual_machine`
- 公钥：
  `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR6bt7uC+1q68ZOQuDtaZTww6SsRJiXwys65cSjHqYq jiaxi@macbook-air codex dual-machine 2026-06-28`
- 已验证 Mac 通过 `127.0.0.1:7897` 代理可以访问 GitHub。

### 游戏本

- Windows 11 家庭中文版 25H2。
- Ryzen 9 7945HX，16GB 内存，RTX 4060 Laptop GPU 8GB。
- NVIDIA 驱动 566.26，显卡侧显示 CUDA 支持到 12.7。
- D 盘总容量约 651.64GB，可用约 245.12GB。
- 建议 WSL 工作空间初始控制在 160GB 以内。
- BIOS 虚拟化已开启，WSL2 CPU 条件满足。
- Clash Verge/Mihomo 监听 `127.0.0.1:7897`，`allow-lan: false`。
- Git、OpenSSH Client、Windows Terminal、Anaconda 已安装。
- OpenSSH Server、Tailscale、Docker Desktop、Mamba/Micromamba 未发现。
- WSL2 已可用，当前安装在 `D:\WSL\Ubuntu`。
- 已从 Ubuntu 26.04 重装为 Ubuntu 24.04.4 LTS。
- WSL 发行版：`Ubuntu-24.04`，WSL 版本 `2`。
- WSL 默认用户：`jiaxi`。
- Python：`3.12.3`。
- Git：`2.43.0`。
- WSL 内 SSH、systemd、GPU、`libcuda.so` 已验证可用。
- WSL IP：`172.28.122.115`。
- WSL 视角 Windows host IP：`172.28.112.1`。
- 为完成 apt 安装，WSL 内临时固定 DNS 为 `1.1.1.1` 和 `8.8.8.8`。

## Mac 侧待办

- 已完成：生成 Mac 主控专用 SSH key：`~/.ssh/id_ed25519_codex_dual_machine`。
- 等游戏本 WSL 确认为 Ubuntu 24.04 后，把 Mac 公钥加入 WSL 用户 `jiaxi` 的 `~/.ssh/authorized_keys`。
- 等拿到 Tailscale 名称或 IP 后，把 `dual-machine/ssh-config-template` 合并到 `~/.ssh/config`。
- 决定是否安装 Tailscale Mac 客户端。
- 决定 GitHub/Gitee 策略：建议 GitHub 为主，Gitee 作为国内镜像或备用 remote。

## 代理策略

- Mac 本机 Clash/Mihomo 端口：`127.0.0.1:7897`。
- Mac 临时启用 shell 和 Git 代理：
  `source dual-machine/mac-proxy.sh on`
- Mac 临时关闭 shell 和 Git 代理：
  `source dual-machine/mac-proxy.sh off`
- WSL 后续需要通过 Windows host IP 访问 Windows Clash 端口，或者调整 Clash 配置允许 WSL 访问。
- 推荐优先使用 Windows `netsh interface portproxy`：只在 WSL NAT host IP 上监听 `7898`，转发到 Windows `127.0.0.1:7897`。
- 不优先使用 Clash `allow-lan`，因为它可能把代理暴露给局域网。

## 验收目标

- Mac 可执行：`ssh legion-wsl`。
- WSL 可执行：`nvidia-smi`。
- WSL PyTorch 验证：`torch.cuda.is_available()` 返回 `True`。
- Mac/Codex 可通过 SSH 操作 WSL 工作目录。
