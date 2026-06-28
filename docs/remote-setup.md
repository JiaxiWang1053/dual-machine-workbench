# Git Remote Setup

本仓库已经在 Mac 侧初始化。为了让游戏本 Codex 访问，需要添加一个远端。

## 推荐路线

优先使用 GitHub private repo：

```bash
git remote add origin git@github.com:YOUR_ACCOUNT/dual-machine-workbench.git
git push -u origin main
```

本机当前实际远端：

```text
origin -> git@github.com:JiaxiWang1053/dual-machine-workbench.git
```

Mac 侧当前使用专用 SSH key：

```text
~/.ssh/id_ed25519_codex_dual_machine
```

对应公钥：

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR6bt7uC+1q68ZOQuDtaZTww6SsRJiXwys65cSjHqYq jiaxi@macbook-air codex dual-machine 2026-06-28
```

需要把这把公钥添加到 GitHub：

```text
GitHub -> Settings -> SSH and GPG keys -> New SSH key
Title: MacBook Air Codex Dual Machine
Key: 上面的 ssh-ed25519 公钥
```

当前仓库已配置 `core.sshCommand`，会通过 Mac Clash/Mihomo `127.0.0.1:7897` 连接 GitHub SSH。

如果国内访问不稳定，再添加 Gitee mirror：

```bash
git remote add gitee git@gitee.com:YOUR_ACCOUNT/dual-machine-workbench.git
git push -u gitee main
```

## 游戏本侧拉取

在 Windows 或 WSL 中执行：

```bash
git clone REMOTE_URL dual-machine-workbench
cd dual-machine-workbench
```

然后让游戏本 Codex 从这里开始：

```text
请阅读 README.md、docs/status.md 和 tasks/ 中的任务。
当前先执行 tasks/game-laptop-001-reinstall-ubuntu-24.04.md。
完成后把结果写入 reports/，提交并推送。
```

## 代理提醒

Mac 侧可临时启用代理：

```bash
source scripts/mac-proxy.sh on
```

游戏本 WSL 侧代理尚未配置完成，所以如果在 WSL 内无法访问 GitHub，先在 Windows PowerShell 或 Codex 中拉取仓库，或者先完成 `tasks/game-laptop-002-wsl-proxy.md`。
