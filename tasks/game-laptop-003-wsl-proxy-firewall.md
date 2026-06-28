# Task: Allow WSL NAT Access to Windows Proxy Port

请在游戏本 Codex 上执行本任务。

## 背景

`tasks/game-laptop-002-wsl-proxy.md` 已执行，结果：

- Windows Clash/Mihomo 监听：`127.0.0.1:7897`
- Windows `netsh interface portproxy` 已创建：
  `172.28.112.1:7898 -> 127.0.0.1:7897`
- Windows 自己访问 `172.28.112.1:7898` 成功。
- WSL 访问 `172.28.112.1:7898` 超时。

判断：

- 最可能是 Windows/Hyper-V firewall 阻止 WSL VM/NAT 网络访问 Windows host 监听端口。

## 目标

添加一个尽量窄的 Windows 防火墙允许规则：

- 只允许 WSL NAT 网段访问本机 TCP `7898`
- 不开放 Clash `7897`
- 不启用 Clash `allow-lan`
- 不修改 Windows 防火墙以外的内容
- 不安装软件

## 边界

- 需要管理员 PowerShell。
- 不改 Clash 配置。
- 不改 Windows 启动流程。
- 不安装 Docker、CUDA Toolkit、PyTorch、Tailscale。
- 不删除现有 portproxy 规则，除非需要重建同一条 `7898 -> 7897` 规则。

## 执行前检查

在管理员 PowerShell 中确认：

```powershell
wsl -d Ubuntu-24.04 -- ip route
netsh interface portproxy show v4tov4
netstat -ano | findstr 7898
```

确认 WSL route 类似：

```text
default via 172.28.112.1 dev eth0
172.28.112.0/20 dev eth0 proto kernel scope link src 172.28.122.115
```

从第二行提取 WSL NAT 网段，例如：

```text
172.28.112.0/20
```

从 `default via` 提取 Windows host IP，例如：

```text
172.28.112.1
```

## 添加防火墙规则

规则名：

```text
Codex WSL Proxy 7898
```

如果同名规则已存在，先报告并删除旧规则，再添加新规则。

管理员 PowerShell：

```powershell
Remove-NetFirewallRule -DisplayName "Codex WSL Proxy 7898" -ErrorAction SilentlyContinue

New-NetFirewallRule `
  -DisplayName "Codex WSL Proxy 7898" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalAddress <WSL_HOST_IP> `
  -LocalPort 7898 `
  -RemoteAddress <WSL_NAT_CIDR> `
  -Profile Any `
  -Description "Allow WSL NAT clients to reach Windows portproxy 7898 for local Clash/Mihomo proxy only"
```

示例：

```powershell
New-NetFirewallRule `
  -DisplayName "Codex WSL Proxy 7898" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalAddress 172.28.112.1 `
  -LocalPort 7898 `
  -RemoteAddress 172.28.112.0/20 `
  -Profile Any `
  -Description "Allow WSL NAT clients to reach Windows portproxy 7898 for local Clash/Mihomo proxy only"
```

## 测试

在 WSL 中测试 TCP：

```bash
timeout 5 bash -c '</dev/tcp/<WSL_HOST_IP>/7898' && echo TCP_OK || echo TCP_FAIL
```

在 WSL 中测试 GitHub：

```bash
curl -I --connect-timeout 10 -x http://<WSL_HOST_IP>:7898 https://github.com
```

如果成功，创建代理 helper：

```bash
mkdir -p /home/jiaxi/bin
cat > /home/jiaxi/bin/proxy <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

WSL_HOST_IP="$(ip route | awk '/default/ {print $3; exit}')"
PROXY_URL="http://${WSL_HOST_IP}:7898"

case "${1:-on}" in
  on)
    export HTTP_PROXY="${PROXY_URL}"
    export HTTPS_PROXY="${PROXY_URL}"
    export ALL_PROXY="${PROXY_URL}"
    export http_proxy="${PROXY_URL}"
    export https_proxy="${PROXY_URL}"
    export all_proxy="${PROXY_URL}"
    git config --global http.proxy "${PROXY_URL}"
    git config --global https.proxy "${PROXY_URL}"
    echo "Proxy enabled: ${PROXY_URL}"
    ;;
  off)
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy
    git config --global --unset http.proxy 2>/dev/null || true
    git config --global --unset https.proxy 2>/dev/null || true
    echo "Proxy disabled"
    ;;
  show)
    echo "${PROXY_URL}"
    ;;
  *)
    echo "Usage: source ~/bin/proxy [on|off|show]" >&2
    return 2 2>/dev/null || exit 2
    ;;
esac
EOF
chmod +x /home/jiaxi/bin/proxy
chown jiaxi:jiaxi /home/jiaxi/bin/proxy
```

然后验证：

```bash
source /home/jiaxi/bin/proxy on
git ls-remote https://github.com/JiaxiWang1053/dual-machine-workbench.git HEAD
python3 -m pip index versions torch | head -n 20
```

如果 `pip index` 命令不支持或报错，只报告错误，不要安装 PyTorch。

## 回滚命令

如果规则导致异常，管理员 PowerShell 回滚：

```powershell
Remove-NetFirewallRule -DisplayName "Codex WSL Proxy 7898" -ErrorAction SilentlyContinue
netsh interface portproxy delete v4tov4 listenaddress=<WSL_HOST_IP> listenport=7898
```

## 报告要求

把结果写入：

```text
reports/game-laptop-003-wsl-proxy-firewall.md
```

报告必须包含：

- WSL route 输出
- WSL host IP
- WSL NAT CIDR
- portproxy 表
- firewall rule 详情
- WSL TCP 测试结果
- WSL curl GitHub 结果
- `/home/jiaxi/bin/proxy` 是否创建
- `git ls-remote` 结果
- `pip index versions torch` 结果或错误
- 是否执行了回滚

