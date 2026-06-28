# Game Laptop 005: Private WLAN and WSL SSH Bridge

Date: 2026-06-29

## Summary

Task `tasks/game-laptop-005-private-wlan-ssh-bridge.md` was executed.

Completed:

- Current active `WLAN` profile was changed from `Public` to `Private`.
- WSL SSH service was confirmed active.
- Windows LAN IP was detected as `192.168.2.5`.
- WSL IP was detected as `172.28.122.115`.
- Windows `portproxy` was created:

```text
192.168.2.5:2222 -> 172.28.122.115:22
```

- Windows firewall rule `Codex WSL SSH LAN 2222` was created for `Private` profile, `LocalSubnet`, TCP `2222`.
- Windows `Test-NetConnection 192.168.2.5:2222` succeeded.

Important issue:

- Windows OpenSSH client test to `192.168.2.5:2222` did not reach normal authentication. It connected, then failed during banner/key-exchange with timeout/reset.
- Additional diagnostics show Windows can SSH to WSL through `127.0.0.1:22`, but Windows cannot SSH directly to the WSL NAT IP `172.28.122.115:22`.

No rollback was executed.

## Network Profile Before

```text
NetworkCategory          : Public
IPv4Connectivity         : Internet
InterfaceAlias           : WLAN
Name                     : MathyS_5G
```

## Network Profile After

```text
NetworkCategory          : Private
IPv4Connectivity         : Internet
InterfaceAlias           : WLAN
Name                     : MathyS_5G
```

## WSL SSH Service Status

Command:

```powershell
wsl -d Ubuntu-24.04 -- bash -lc "systemctl is-active ssh && ss -ltnp | grep ':22 ' && hostname -I"
```

Result:

```text
active
LISTEN 0      4096          0.0.0.0:22        0.0.0.0:*
LISTEN 0      4096             [::]:22           [::]:*
172.28.122.115
```

WSL IP:

```text
172.28.122.115
```

## Windows LAN IP

IPv4 candidates:

```text
InterfaceAlias                     IPAddress    PrefixLength AddressState
--------------                     ---------    ------------ ------------
vEthernet (WSL (Hyper-V firewall)) 172.28.112.1           20 Preferred
WLAN                               192.168.2.5            24 Preferred
本地连接                           10.8.8.1               24 Tentative
```

Selected Windows LAN IP:

```text
192.168.2.5
```

## Portproxy Table

```text
Listen on ipv4:             Connect to ipv4:

Address         Port        Address         Port
--------------- ----------  --------------- ----------
172.28.112.1    7898        127.0.0.1       7897
192.168.2.5     2222        172.28.122.115  22
```

## Firewall Rule

Rule:

```text
DisplayName : Codex WSL SSH LAN 2222
Enabled     : True
Profile     : Private
Direction   : Inbound
Action      : Allow
Description : Allow LAN clients to SSH into WSL Ubuntu through Windows portproxy on TCP 2222
```

Address filter:

```text
LocalAddress  : 192.168.2.5
RemoteAddress : LocalSubnet
```

Port filter:

```text
Protocol  : TCP
LocalPort : 2222
```

## Windows Test-NetConnection

Command:

```powershell
Test-NetConnection -ComputerName 192.168.2.5 -Port 2222
```

Result:

```text
ComputerName            : 192.168.2.5
RemoteAddress           : 192.168.2.5
RemotePort              : 2222
InterfaceAlias          : WLAN
NetworkIsolationContext : Private Network
TcpTestSucceeded        : True
```

## Windows SSH Test

Command:

```powershell
ssh -p 2222 -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no jiaxi@192.168.2.5
```

Initial result from the administrator script:

```text
kex_exchange_identification: read: Connection reset
Connection reset by 192.168.2.5 port 2222
```

Follow-up verbose test:

```text
Connection established.
Local version string SSH-2.0-OpenSSH_for_Windows_9.5
Connection timed out during banner exchange
Connection to 192.168.2.5 port 2222 timed out
```

Status: not ready for Mac validation yet.

## Additional Diagnostics

Windows direct SSH to WSL NAT IP timed out:

```powershell
ssh -vvv -p 22 -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no jiaxi@172.28.122.115
```

Result:

```text
connect to address 172.28.122.115 port 22: Connection timed out
ssh: connect to host 172.28.122.115 port 22: Connection timed out
```

WSL local SSH works:

```bash
ssh -vvv -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no localhost true
```

Result ended as expected because no local private key was available:

```text
jiaxi@localhost: Permission denied (publickey,password).
```

Windows localhost to WSL forwarded SSH also works:

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 22
ssh -vvv -p 22 -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no jiaxi@127.0.0.1
```

Results:

```text
TcpTestSucceeded : True
jiaxi@127.0.0.1: Permission denied (publickey,password).
```

This suggests WSL localhost forwarding is working on Windows, but Windows host to WSL NAT IP `172.28.122.115:22` is not reachable.

## Mac SSH Connection Config

The intended Mac config from this task is:

```text
HostName: 192.168.2.5
Port: 2222
User: jiaxi
IdentityFile: ~/.ssh/id_ed25519_codex_dual_machine
```

However, Mac-side testing should wait until the bridge issue is resolved, because Windows SSH testing to `192.168.2.5:2222` did not reach normal authentication.

## Rollback

Rollback executed: no.

Current rollback commands if needed:

```powershell
Remove-NetFirewallRule -DisplayName "Codex WSL SSH LAN 2222" -ErrorAction SilentlyContinue
netsh interface portproxy delete v4tov4 listenaddress=192.168.2.5 listenport=2222
```

If the WLAN profile should be changed back:

```powershell
Set-NetConnectionProfile -InterfaceAlias "WLAN" -NetworkCategory Public
```

## Recommended Next Step

Ask the Mac side to decide the next bridge strategy.

Most promising option from diagnostics:

```text
192.168.2.5:2222 -> 127.0.0.1:22
```

Reason: Windows can reach WSL SSH via `127.0.0.1:22`, while Windows cannot reach `172.28.122.115:22` directly.

This was not applied in this task because the task explicitly specified forwarding to the WSL IP.
