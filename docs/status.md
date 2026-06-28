# 状态板

## 已完成

- Mac 基础检查。
- Mac Clash/Mihomo 端口确认：`127.0.0.1:7897`。
- Mac 通过代理访问 GitHub 验证成功。
- Mac 生成专用 SSH key：`~/.ssh/id_ed25519_codex_dual_machine`。
- GitHub 协作仓库已建立并推送。
- 游戏本已从误装的 Ubuntu 26.04 重装为明确的 Ubuntu 24.04 LTS。
- 游戏本 WSL 安装路径：`D:\WSL\Ubuntu`。
- 游戏本 WSL 发行版：`Ubuntu-24.04`，WSL 版本 `2`。
- 游戏本 WSL 默认用户：`jiaxi`。
- 游戏本 WSL Python：`3.12.3`。
- 游戏本 WSL Git：`2.43.0`。
- 游戏本 WSL 内 systemd、SSH、GPU、`libcuda.so` 验证成功。
- 游戏本 WSL 内基础工具已安装，包括 `build-essential`、`git`、`openssh-server`、`tmux`、`htop`、`nvtop`、`python3`、`python3-venv`、`python3-pip`。
- 游戏本 WSL IP：`172.28.122.115`。
- WSL 视角 Windows host IP：`172.28.112.1`。

## 当前阻塞

- WSL 直连 GitHub 不稳定或超时。
- Windows Clash/Mihomo 仅监听 `127.0.0.1:7897`，WSL 当前无法直接访问该端口。
- 游戏本 WSL 为完成 apt 安装临时固定 DNS：`1.1.1.1` 和 `8.8.8.8`。

## 下一步

1. 游戏本配置 WSL 使用 Windows Clash 代理，执行 `tasks/game-laptop-002-wsl-proxy.md`。
2. 把 Mac 公钥加入 WSL `jiaxi` 用户。
3. Mac 配置 `ssh legion-wsl`。
4. 安装和配置 Tailscale。
5. 建立 Python/PyTorch CUDA 环境。
6. 根据代理稳定性决定是否保留 WSL 固定 DNS。
