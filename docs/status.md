# 状态板

## 已完成

- Mac 基础检查。
- Mac Clash/Mihomo 端口确认：`127.0.0.1:7897`。
- Mac 通过代理访问 GitHub 验证成功。
- Mac 生成专用 SSH key：`~/.ssh/id_ed25519_codex_dual_machine`。
- 游戏本 WSL2 基础安装验证成功，但当前误装 Ubuntu 26.04。
- 游戏本 WSL 内 systemd、SSH、GPU、`libcuda.so` 验证成功。

## 当前阻塞

- 游戏本 WSL 当前为 Ubuntu 26.04 LTS，Python 3.14.4。
- 建议重装为 Ubuntu 24.04 LTS 后再继续 PyTorch 环境。

## 下一步

1. 游戏本重装 WSL Ubuntu 24.04 到 `D:\WSL\Ubuntu`。
2. 游戏本配置 WSL 使用 Windows Clash 代理。
3. 把 Mac 公钥加入 WSL `jiaxi` 用户。
4. Mac 配置 `ssh legion-wsl`。
5. 安装和配置 Tailscale。
6. 建立 Python/PyTorch CUDA 环境。

