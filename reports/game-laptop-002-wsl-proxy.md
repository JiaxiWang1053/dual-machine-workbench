# Game Laptop 002: WSL Proxy Through Windows Clash

Date: 2026-06-28

## Summary

Task `tasks/game-laptop-002-wsl-proxy.md` was executed on the game laptop.

The Windows `netsh interface portproxy` rule was created successfully:

```text
172.28.112.1:7898 -> 127.0.0.1:7897
```

However, WSL could not connect to `172.28.112.1:7898`; TCP and curl tests from WSL timed out. Because the proxy test failed, `/home/jiaxi/bin/proxy` was not created.

## Environment

- WSL distribution: `Ubuntu-24.04`
- WSL user: `jiaxi`
- WSL host IP from `ip route`: `172.28.112.1`
- WSL guest IP from `ip route`: `172.28.122.115`
- Windows Clash/Mihomo local proxy: `127.0.0.1:7897`
- Candidate WSL proxy endpoint: `172.28.112.1:7898`

## Commands and Results

### WSL route

```text
default via 172.28.112.1 dev eth0 proto kernel
172.28.112.0/20 dev eth0 proto kernel scope link src 172.28.122.115
```

### Portproxy

Command executed from administrator PowerShell:

```powershell
netsh interface portproxy add v4tov4 listenaddress=172.28.112.1 listenport=7898 connectaddress=127.0.0.1 connectport=7897
```

Result:

```text
EXITCODE: 0
```

Current portproxy table:

```text
Listen on ipv4:             Connect to ipv4:

Address         Port        Address         Port
--------------- ----------  --------------- ----------
172.28.112.1    7898        127.0.0.1       7897
```

### Windows listener check

```text
TCP    172.28.112.1:7898      0.0.0.0:0              LISTENING       5928
```

### Windows proxy checks

Windows can access GitHub through Clash directly:

```powershell
curl.exe -I --connect-timeout 10 -x http://127.0.0.1:7897 https://github.com
```

Result:

```text
HTTP/1.1 200 Connection established
HTTP/1.1 200 OK
```

Windows can also access GitHub through the portproxy endpoint:

```powershell
curl.exe -I --connect-timeout 10 -x http://172.28.112.1:7898 https://github.com
```

Result:

```text
HTTP/1.1 200 Connection established
HTTP/1.1 200 OK
```

Windows TCP check:

```powershell
Test-NetConnection -ComputerName 172.28.112.1 -Port 7898
```

Result:

```text
TcpTestSucceeded: True
InterfaceAlias: vEthernet (WSL (Hyper-V firewall))
```

### WSL proxy checks

WSL TCP test:

```bash
timeout 5 bash -c '</dev/tcp/172.28.112.1/7898' && echo TCP_OK || echo TCP_FAIL
```

Result:

```text
TCP_FAIL
```

WSL curl test:

```bash
curl -v --connect-timeout 10 -x http://172.28.112.1:7898 https://github.com
```

Result:

```text
* Trying 172.28.112.1:7898...
* ipv4 connect timeout after 10000ms, move on!
* Failed to connect to 172.28.112.1 port 7898 after 10086 ms: Timeout was reached
curl: (28) Failed to connect to 172.28.112.1 port 7898 after 10086 ms: Timeout was reached
```

## Files Created

- `scripts/game-laptop-002-wsl-proxy-admin.ps1`
- `scripts/run-game-laptop-002-admin.cmd`
- `reports/game-laptop-002-wsl-proxy.log`

## Status

- Portproxy rule created: yes
- Windows direct Clash proxy usable: yes
- Windows portproxy endpoint usable from Windows: yes
- WSL can connect to portproxy endpoint: no
- WSL proxy helper created: no
- Windows firewall modified: no
- Clash configuration modified: no
- New software installed: no

## Likely Cause

The most likely blocker is traffic from the WSL VM/NAT network to the Windows host listener on `172.28.112.1:7898`. The portproxy listener exists and works locally on Windows, but WSL cannot open a TCP connection to it.

The `Test-NetConnection` output identifies the interface as:

```text
vEthernet (WSL (Hyper-V firewall))
```

This suggests the next decision may involve Windows Firewall or Hyper-V firewall policy for WSL. This was not changed because the task boundary explicitly said not to modify Windows firewall unless later requested.

## Recommended Next Step

Ask the Mac side to decide between these options:

1. Add a narrowly scoped Windows/Hyper-V firewall allowance for WSL NAT traffic to `172.28.112.1:7898`.
2. Use Clash/Mihomo `allow-lan` only if the exposure is acceptable and properly constrained.
3. Try WSL mirrored networking if compatible with this Windows build and acceptable for the machine.

Option 1 appears closest to the current design because it keeps Clash listening on Windows localhost and exposes only the WSL host-side proxy port.
