# Dual Machine Workbench

这个仓库用于协调 MacBook Air 和联想拯救者 R9000P 的双机工作环境搭建。

## 目标

- Mac 作为主控工作站，负责开发、浏览、Git、文档和 Codex 协调。
- 游戏本保持 Windows 娱乐优先，在 Windows 内通过 WSL2 Ubuntu 提供 Linux 工作节点。
- Mac 通过 SSH/Tailscale 连接游戏本 WSL。
- WSL 支持 Python、PyTorch、CUDA、代理、tmux 和 Codex。

## 当前决策

- Linux 形态：WSL2，不做双系统。
- WSL 位置：`D:\WSL\Ubuntu`。
- WSL 用户名：`jiaxi`。
- 推荐发行版：Ubuntu 24.04 LTS。
- 不在 WSL 内安装 Linux NVIDIA driver。
- 代理优先使用 Windows `netsh interface portproxy` 转发 Clash/Mihomo，而不是直接开启 Clash `allow-lan`。

## 两边 Codex 协作方式

1. Mac 侧维护本仓库和任务文档。
2. 游戏本侧拉取仓库，执行 `tasks/game-laptop-*.md` 中的任务。
3. 游戏本侧把执行结果写入 `reports/`，提交并推送。
4. Mac 侧拉取结果，继续生成下一阶段任务。

## 文件结构

- `tasks/`：给游戏本 Codex 或 Mac Codex 执行的任务。
- `reports/`：执行结果和检查报告。
- `scripts/`：可复用脚本。
- `templates/`：配置模板。
- `docs/`：设计决策和操作说明。
- `outputs/`：用户可直接查看的交付文档。

## 首次远端建议

仓库可以先放 GitHub private repo；如果国内访问不稳定，再加 Gitee mirror。

推荐 remote：

```text
origin -> GitHub private repo
gitee  -> Gitee mirror
```

远端配置步骤见 `docs/remote-setup.md`。
