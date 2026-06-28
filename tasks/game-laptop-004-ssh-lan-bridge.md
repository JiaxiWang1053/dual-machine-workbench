# Task: Add Mac SSH Key and Expose WSL SSH on LAN

请在游戏本 Codex 上执行本任务。

## 背景

当前状态：

- WSL Ubuntu 24.04 已安装并运行。
- WSL 用户：`jiaxi`
- WSL 内 `ssh.service` 已启用并监听 `0.0.0.0:22`。
- WSL 代理已打通，可访问 GitHub、Git 和 PyPI。
- Mac 已生成专用 SSH key。

目标是先打通一条局域网 SSH 链路：

```text
Mac -> Windows LAN IP:2222 -> WSL Ubuntu:22
```

这是后续 VS Code Remote SSH、Codex 远程操作、Tailscale 验证前的基础链路。

## 边界

- 需要管理员 PowerShell。
- 不安装 Tailscale。
- 不安装 Docker、CUDA Toolkit、PyTorch。
- 不改 Clash 配置。
- 不开放 Windows OpenSSH Server。
- 不把 SSH 暴露到 `0.0.0.0`。
- 不开启密码免密以外的新认证方式。
- 只允许局域网访问 Windows TCP `2222`。

## Mac 公钥

把下面这把公钥加入 WSL 用户 `jiaxi` 的 `/home/jiaxi/.ssh/authorized_keys`：

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR6bt7uC+1q68ZOQuDtaZTww6SsRJiXwys65cSjHqYq jiaxi@macbook-air codex dual-machine 2026-06-28
```

## 执行步骤

### 1. 更新仓库

先确保游戏本仓库是最新：

```powershell
git pull
```

### 2. 在 WSL 内添加 Mac 公钥

从 Windows PowerShell 执行：

```powershell
wsl -d Ubuntu-24.04 -u root -- bash -lc "install -d -m 700 -o jiaxi -g jiaxi /home/jiaxi/.ssh"
wsl -d Ubuntu-24.04 -u root -- bash -lc "grep -qxF 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR6bt7uC+1q68ZOQuDtaZTww6SsRJiXwys65cSjHqYq jiaxi@macbook-air codex dual-machine 2026-06-28' /home/jiaxi/.ssh/authorized_keys 2>/dev/null || echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR6bt7uC+1q68ZOQuDtaZTww6SsRJiXwys65cSjHqYq jiaxi@macbook-air codex dual-machine 2026-06-28' >> /home/jiaxi/.ssh/authorized_keys"
wsl -d Ubuntu-24.04 -u root -- bash -lc "chown jiaxi:jiaxi /home/jiaxi/.ssh/authorized_keys && chmod 600 /home/jiaxi/.ssh/authorized_keys"
```

验证：

```powershell
wsl -d Ubuntu-24.04 -u jiaxi -- bash -lc "tail -n 1 ~/.ssh/authorized_keys && ls -ld ~/.ssh && ls -l ~/.ssh/authorized_keys"
```

### 3. 确认 WSL SSH

```powershell
wsl -d Ubuntu-24.04 -- bash -lc "systemctl is-active ssh && ss -ltnp | grep ':22 '"
wsl -d Ubuntu-24.04 -- hostname -I
```

记录 WSL IP，例如：

```text
172.28.122.115
```

### 4. 获取 Windows 局域网 IPv4

在管理员 PowerShell 中列出当前活跃 IPv4：

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.254.*" -and
    $_.PrefixOrigin -ne "WellKnown"
  } |
  Select-Object InterfaceAlias,IPAddress,PrefixLength,AddressState
```

选择当前 Mac 所在网络可访问的游戏本 LAN IP，通常是 Wi-Fi 或 Ethernet 地址，例如：

```text
192.168.x.x
10.x.x.x
172.16-31.x.x
```

不要使用：

- `127.0.0.1`
- `172.28.x.x` 这种 WSL NAT 地址
- `169.254.x.x`

如果无法确定 LAN IP，请停止并报告候选地址，不要继续创建端口转发。

### 5. 创建 Windows portproxy

假设：

- Windows LAN IP 为 `<WINDOWS_LAN_IP>`
- WSL IP 为 `<WSL_IP>`

管理员 PowerShell：

```powershell
netsh interface portproxy delete v4tov4 listenaddress=<WINDOWS_LAN_IP> listenport=2222
netsh interface portproxy add v4tov4 listenaddress=<WINDOWS_LAN_IP> listenport=2222 connectaddress=<WSL_IP> connectport=22
netsh interface portproxy show v4tov4
```

### 6. 添加窄防火墙规则

规则名：

```text
Codex WSL SSH LAN 2222
```

管理员 PowerShell：

```powershell
Remove-NetFirewallRule -DisplayName "Codex WSL SSH LAN 2222" -ErrorAction SilentlyContinue

New-NetFirewallRule `
  -DisplayName "Codex WSL SSH LAN 2222" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalAddress <WINDOWS_LAN_IP> `
  -LocalPort 2222 `
  -RemoteAddress LocalSubnet `
  -Profile Private `
  -Description "Allow LAN clients to SSH into WSL Ubuntu through Windows portproxy on TCP 2222"
```

如果当前网络配置文件不是 `Private`，不要改网络 profile。请报告 profile 状态并停止在防火墙步骤。

检查 profile：

```powershell
Get-NetConnectionProfile | Select-Object InterfaceAlias,NetworkCategory,IPv4Connectivity
```

### 7. Windows 侧本地测试

Windows PowerShell：

```powershell
Test-NetConnection -ComputerName <WINDOWS_LAN_IP> -Port 2222
```

如果 Windows 上有 OpenSSH client，也可以测试 SSH banner：

```powershell
ssh -p 2222 -o BatchMode=yes -o ConnectTimeout=5 jiaxi@<WINDOWS_LAN_IP>
```

这个命令可能因为没有私钥而显示 `Permission denied`，这可以接受；只要不是连接超时即可。

### 8. 给 Mac 的连接信息

报告给 Mac：

```text
HostName: <WINDOWS_LAN_IP>
Port: 2222
User: jiaxi
IdentityFile: ~/.ssh/id_ed25519_codex_dual_machine
```

Mac 侧之后将测试：

```bash
ssh -i ~/.ssh/id_ed25519_codex_dual_machine -p 2222 jiaxi@<WINDOWS_LAN_IP> 'hostname && whoami && nvidia-smi --query-gpu=name --format=csv,noheader'
```

## 回滚命令

管理员 PowerShell：

```powershell
Remove-NetFirewallRule -DisplayName "Codex WSL SSH LAN 2222" -ErrorAction SilentlyContinue
netsh interface portproxy delete v4tov4 listenaddress=<WINDOWS_LAN_IP> listenport=2222
```

不要删除 `/home/jiaxi/.ssh/authorized_keys`，除非用户明确要求撤销 Mac 访问。

## 报告要求

把结果写入：

```text
reports/game-laptop-004-ssh-lan-bridge.md
```

报告必须包含：

- Mac 公钥是否加入
- `authorized_keys` 权限
- WSL SSH 服务状态
- WSL IP
- Windows LAN IP
- Windows network profile 是否为 `Private`
- portproxy 表
- firewall rule 详情
- Windows `Test-NetConnection` 结果
- Windows SSH 测试结果或错误
- 给 Mac 使用的 SSH 连接配置
- 是否执行了回滚

