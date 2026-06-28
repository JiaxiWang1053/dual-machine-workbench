# Game Laptop 003: WSL Proxy Firewall Rule

Date: 2026-06-29

## Summary

Task `tasks/game-laptop-003-wsl-proxy-firewall.md` was executed successfully.

A narrow Windows inbound firewall rule was added to allow only WSL NAT clients to reach the Windows portproxy endpoint:

```text
172.28.112.1:7898 -> 127.0.0.1:7897
```

After the firewall rule was added, WSL could connect to the proxy endpoint, access GitHub through Clash/Mihomo, use Git through the proxy, and query PyPI for `torch` versions.

No Clash configuration was changed. No software was installed. No rollback was executed.

## WSL Route

```text
default via 172.28.112.1 dev eth0 proto kernel
172.28.112.0/20 dev eth0 proto kernel scope link src 172.28.122.115
```

## Detected Network Values

- WSL host IP: `172.28.112.1`
- WSL NAT CIDR: `172.28.112.0/20`
- WSL guest IP: `172.28.122.115`

## Portproxy Table

```text
Listen on ipv4:             Connect to ipv4:

Address         Port        Address         Port
--------------- ----------  --------------- ----------
172.28.112.1    7898        127.0.0.1       7897
```

## Windows Listener

```text
TCP    172.28.112.1:7898      0.0.0.0:0              LISTENING       5928
```

## Firewall Rule

Rule name:

```text
Codex WSL Proxy 7898
```

Rule summary:

```text
DisplayName : Codex WSL Proxy 7898
Enabled     : True
Profile     : Any
Direction   : Inbound
Action      : Allow
Description : Allow WSL NAT clients to reach Windows portproxy 7898 for local Clash/Mihomo proxy only
```

Address filter:

```text
LocalAddress  : 172.28.112.1
RemoteAddress : 172.28.112.0/255.255.240.0
```

Port filter:

```text
Protocol  : TCP
LocalPort : 7898
```

## WSL TCP Test

Command:

```bash
timeout 5 bash -c '</dev/tcp/172.28.112.1/7898' && echo TCP_OK || echo TCP_FAIL
```

Result:

```text
TCP_OK
```

## WSL Curl GitHub Test

Command:

```bash
curl -I --connect-timeout 10 -x http://172.28.112.1:7898 https://github.com
```

Result:

```text
HTTP/1.1 200 Connection established
HTTP/2 200
server: github.com
```

## Proxy Helper

Created:

```text
/home/jiaxi/bin/proxy
```

Helper output:

```bash
source /home/jiaxi/bin/proxy show
```

```text
http://172.28.112.1:7898
```

Usage:

```bash
source /home/jiaxi/bin/proxy on
source /home/jiaxi/bin/proxy off
source /home/jiaxi/bin/proxy show
```

## Git Test

Command:

```bash
source /home/jiaxi/bin/proxy on >/dev/null && git ls-remote https://github.com/JiaxiWang1053/dual-machine-workbench.git HEAD
```

Result:

```text
0aac24e3330e3ab68ae26e5307427ea3a0f22822	HEAD
```

## PyPI / Torch Index Test

Command:

```bash
source /home/jiaxi/bin/proxy on >/dev/null && python3 -m pip index versions torch | head -n 20
```

Result:

```text
WARNING: pip index is currently an experimental command. It may be removed/changed in a future release without prior warning.
torch (2.12.1)
Available versions: 2.12.1, 2.12.0, 2.11.0, 2.10.0, 2.9.1, 2.9.0, 2.8.0, 2.7.1, 2.7.0, 2.6.0, 2.5.1, 2.5.0, 2.4.1, 2.4.0, 2.3.1, 2.3.0, 2.2.2, 2.2.1, 2.2.0
```

## Rollback

Rollback executed: no.

If rollback is needed later, run from administrator PowerShell:

```powershell
Remove-NetFirewallRule -DisplayName "Codex WSL Proxy 7898" -ErrorAction SilentlyContinue
netsh interface portproxy delete v4tov4 listenaddress=172.28.112.1 listenport=7898
```

## Files Created

- `scripts/game-laptop-003-wsl-proxy-firewall-admin.ps1`
- `scripts/run-game-laptop-003-admin.cmd`
- `reports/game-laptop-003-wsl-proxy-firewall.log`
- `reports/game-laptop-003-wsl-proxy-firewall.md`

## Final Status

- Windows portproxy present: yes
- Narrow firewall rule added: yes
- WSL TCP access to `172.28.112.1:7898`: yes
- WSL GitHub access through proxy: yes
- WSL Git access through proxy: yes
- WSL PyPI query through proxy: yes
- Proxy helper created: yes
- Clash configuration changed: no
- Software installed: no
- Rollback executed: no
