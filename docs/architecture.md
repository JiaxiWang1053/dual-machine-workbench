# 双机工作环境架构

## 总体结构

```text
MacBook Air
  - Codex 主控
  - Git / SSH / 浏览器 / 文档
  - 项目代码和说明文档

Windows 游戏本
  - Windows 11 保持娱乐主系统
  - Clash Verge / Mihomo
  - WSL2 Ubuntu 24.04
      - SSH Server
      - Python / PyTorch
      - CUDA through NVIDIA WSL driver bridge
      - tmux / Codex
```

## 远程访问

阶段一使用局域网或 WSL NAT IP 验证 SSH。

阶段二引入 Tailscale：

- Mac 安装 Tailscale 客户端。
- Windows 或 WSL 安装 Tailscale。
- 使用 MagicDNS 或 Tailscale IP 写入 Mac `~/.ssh/config`。

## 代理

Mac 本机 Clash/Mihomo：`127.0.0.1:7897`。

游戏本 Windows Clash/Mihomo：`127.0.0.1:7897`。

WSL 默认无法访问 Windows localhost，因此推荐：

```text
WSL -> Windows host IP:7898 -> 127.0.0.1:7897
```

通过 Windows 管理员 PowerShell 设置 `netsh interface portproxy`。

## 存储

- Mac：代码、文档、Git 仓库。
- WSL：Linux 环境、数据缓存、训练输出。
- 游戏本 D 盘可用空间有限，建议 WSL 初始使用控制在 160GB 以内。

