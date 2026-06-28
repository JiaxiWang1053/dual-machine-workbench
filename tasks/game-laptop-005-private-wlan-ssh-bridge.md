# Task: Mark Trusted WLAN Private and Create WSL SSH Bridge

请在游戏本 Codex 上执行本任务。

## 背景

`tasks/game-laptop-004-ssh-lan-bridge.md` 已部分执行：

- Mac 公钥已加入 WSL 用户 `jiaxi`。
- WSL SSH 服务已验证为 active。
- Windows LAN IP 已识别为 `192.168.2.5`。
- 任务停止在防火墙步骤，因为当前 WLAN profile 是 `Public`。

用户已选择：

```text
把当前可信 WLAN 标记为 Private，然后重跑 LAN SSH bridge。
```

## 目标

建立局域网 SSH 链路：

```text
Mac -> Windows LAN IP:2222 -> WSL Ubuntu:22
```

## 边界

- 需要管理员 PowerShell。
- 只允许修改当前活跃 WLAN 的 network profile：`Public -> Private`。
- 不修改其他网络接口的 profile。
- 不安装 Tailscale、Docker、CUDA Toolkit、PyTorch。
- 不改 Clash 配置。
- 不开放 Windows OpenSSH Server。
- 不监听 `0.0.0.0`。
- SSH bridge 只绑定当前 Windows LAN IP。
- 防火墙规则只用于 `Private` profile + `LocalSubnet` + TCP `2222`。

## 执行前确认

先报告当前网络 profile：

```powershell
Get-NetConnectionProfile | Select-Object InterfaceAlias,NetworkCategory,IPv4Connectivity
```

只允许对满足以下条件的接口执行修改：

- `InterfaceAlias` 是 `WLAN`
- `IPv4Connectivity` 是 `Internet`
- 当前 `NetworkCategory` 是 `Public`

如果条件不满足，请停止并报告。

## Step 1: Mark WLAN Private

管理员 PowerShell：

```powershell
Set-NetConnectionProfile -InterfaceAlias "WLAN" -NetworkCategory Private
```

验证：

```powershell
Get-NetConnectionProfile -InterfaceAlias "WLAN" | Select-Object InterfaceAlias,NetworkCategory,IPv4Connectivity
```

如果不是 `Private`，停止并报告。

## Step 2: Reconfirm WSL SSH and IP

```powershell
wsl -d Ubuntu-24.04 -- bash -lc "systemctl is-active ssh && ss -ltnp | grep ':22 ' && hostname -I"
```

记录 WSL IP，例如：

```text
172.28.122.115
```

## Step 3: Reconfirm Windows LAN IP

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.254.*" -and
    $_.PrefixOrigin -ne "WellKnown"
  } |
  Select-Object InterfaceAlias,IPAddress,PrefixLength,AddressState
```

选择 `WLAN` 的 LAN IP，例如：

```text
192.168.2.5
```

不要使用：

- `127.0.0.1`
- WSL NAT 地址，例如 `172.28.112.1`
- `169.254.x.x`
- Tentative 地址

## Step 4: Create Portproxy

假设：

- Windows LAN IP：`<WINDOWS_LAN_IP>`
- WSL IP：`<WSL_IP>`

管理员 PowerShell：

```powershell
netsh interface portproxy delete v4tov4 listenaddress=<WINDOWS_LAN_IP> listenport=2222
netsh interface portproxy add v4tov4 listenaddress=<WINDOWS_LAN_IP> listenport=2222 connectaddress=<WSL_IP> connectport=22
netsh interface portproxy show v4tov4
```

## Step 5: Create Firewall Rule

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

验证规则：

```powershell
Get-NetFirewallRule -DisplayName "Codex WSL SSH LAN 2222" |
  Format-List DisplayName,Enabled,Profile,Direction,Action,Description

Get-NetFirewallRule -DisplayName "Codex WSL SSH LAN 2222" |
  Get-NetFirewallAddressFilter |
  Format-List LocalAddress,RemoteAddress

Get-NetFirewallRule -DisplayName "Codex WSL SSH LAN 2222" |
  Get-NetFirewallPortFilter |
  Format-List Protocol,LocalPort
```

## Step 6: Windows-Side Test

```powershell
Test-NetConnection -ComputerName <WINDOWS_LAN_IP> -Port 2222
```

Expected:

```text
TcpTestSucceeded: True
```

可选 SSH 测试：

```powershell
ssh -p 2222 -o BatchMode=yes -o ConnectTimeout=5 jiaxi@<WINDOWS_LAN_IP>
```

如果结果是 `Permission denied`，可以接受，表示链路通但 Windows 侧没有对应私钥。

如果是 timeout/refused，请报告并不要继续。

## Step 7: Give Mac Connection Info

报告给 Mac：

```text
HostName: <WINDOWS_LAN_IP>
Port: 2222
User: jiaxi
IdentityFile: ~/.ssh/id_ed25519_codex_dual_machine
```

Mac 侧将测试：

```bash
ssh -i ~/.ssh/id_ed25519_codex_dual_machine -p 2222 jiaxi@<WINDOWS_LAN_IP> 'hostname && whoami && nvidia-smi --query-gpu=name --format=csv,noheader'
```

## Rollback

如果 SSH bridge 规则导致异常，管理员 PowerShell：

```powershell
Remove-NetFirewallRule -DisplayName "Codex WSL SSH LAN 2222" -ErrorAction SilentlyContinue
netsh interface portproxy delete v4tov4 listenaddress=<WINDOWS_LAN_IP> listenport=2222
```

如需把 WLAN profile 改回 Public：

```powershell
Set-NetConnectionProfile -InterfaceAlias "WLAN" -NetworkCategory Public
```

不要删除 `/home/jiaxi/.ssh/authorized_keys`，除非用户明确要求撤销 Mac 访问。

## 报告要求

把结果写入：

```text
reports/game-laptop-005-private-wlan-ssh-bridge.md
```

报告必须包含：

- 修改前 network profile
- 修改后 network profile
- WSL SSH 服务状态
- WSL IP
- Windows LAN IP
- portproxy 表
- firewall rule 详情
- Windows `Test-NetConnection` 结果
- Windows SSH 测试结果或错误
- 给 Mac 使用的 SSH 连接配置
- 是否执行了回滚

