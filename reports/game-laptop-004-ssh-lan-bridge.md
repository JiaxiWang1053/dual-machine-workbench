# Game Laptop 004: SSH LAN Bridge

Date: 2026-06-29

## Summary

Task `tasks/game-laptop-004-ssh-lan-bridge.md` was partially executed.

The Mac public key was added to WSL user `jiaxi` successfully, and WSL SSH was verified as active.

The LAN bridge was not created because the active Windows network profile is `Public`. The task explicitly says not to change the network profile and to stop at the firewall step if the profile is not `Private`.

No Windows SSH portproxy for TCP `2222` was created. No firewall rule for TCP `2222` was created. No rollback was needed.

## Mac Public Key

Added to:

```text
/home/jiaxi/.ssh/authorized_keys
```

Public key:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR6bt7uC+1q68ZOQuDtaZTww6SsRJiXwys65cSjHqYq jiaxi@macbook-air codex dual-machine 2026-06-28
```

Verification:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR6bt7uC+1q68ZOQuDtaZTww6SsRJiXwys65cSjHqYq jiaxi@macbook-air codex dual-machine 2026-06-28
drwx------ 2 jiaxi jiaxi 4096 Jun 29 00:27 /home/jiaxi/.ssh
-rw------- 1 jiaxi jiaxi 129 Jun 29 00:27 /home/jiaxi/.ssh/authorized_keys
```

Status: added successfully.

## WSL SSH Service

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

## Windows LAN IP Candidates

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

Reason:

- `172.28.112.1` is the WSL NAT host IP, not the LAN IP.
- `10.8.8.1` is tentative and not selected.
- `192.168.2.5` is the active WLAN LAN address.

## Windows Network Profile

Command:

```powershell
Get-NetConnectionProfile | Select-Object InterfaceAlias,NetworkCategory,IPv4Connectivity
```

Result:

```text
InterfaceAlias: WLAN
NetworkCategory: Public
IPv4Connectivity: Internet
```

Status: not `Private`.

The task says:

```text
If the current network profile is not Private, do not change the network profile. Report the profile state and stop at the firewall step.
```

Therefore execution was stopped before creating the LAN SSH bridge.

## Portproxy Table

Existing portproxy table after stopping:

```text
Listen on ipv4:             Connect to ipv4:

Address         Port        Address         Port
--------------- ----------  --------------- ----------
172.28.112.1    7898        127.0.0.1       7897
```

No SSH bridge rule was created:

```text
192.168.2.5:2222 -> 172.28.122.115:22
```

## Firewall Rule

Rule name:

```text
Codex WSL SSH LAN 2222
```

Status: not created.

Reason: active network profile is `Public`, not `Private`.

## Windows Test-NetConnection

Not executed because the `2222` portproxy and firewall rule were not created.

## Windows SSH Test

Not executed because the `2222` portproxy and firewall rule were not created.

## Mac SSH Connection Config

Not ready yet. Planned config once the LAN bridge is allowed:

```text
HostName: 192.168.2.5
Port: 2222
User: jiaxi
IdentityFile: ~/.ssh/id_ed25519_codex_dual_machine
```

Mac-side planned test:

```bash
ssh -i ~/.ssh/id_ed25519_codex_dual_machine -p 2222 jiaxi@192.168.2.5 'hostname && whoami && nvidia-smi --query-gpu=name --format=csv,noheader'
```

## Rollback

Rollback executed: no.

No TCP `2222` portproxy or firewall rule was created, so there was nothing to roll back.

The Mac public key remains in `/home/jiaxi/.ssh/authorized_keys`, as instructed by the task.

## Next Decision Needed

Mac/user side should decide one of the following:

1. Manually mark this trusted WLAN as `Private`, then rerun the LAN SSH bridge task.
2. Keep WLAN as `Public` and wait for Tailscale-based SSH instead.
3. Provide a revised task that allows a different firewall rule strategy for the current `Public` profile.
