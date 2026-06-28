$ErrorActionPreference = "Continue"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ReportDir = Join-Path $RepoRoot "reports"
$LogPath = Join-Path $ReportDir "game-laptop-005-private-wlan-ssh-bridge.log"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

function Log {
  param([string]$Message)
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Write-Host $line
  Add-Content -Encoding UTF8 -Path $LogPath -Value $line
}

function Run-Capture {
  param(
    [string]$Title,
    [string]$FilePath,
    [string[]]$Arguments
  )
  Log ""
  Log "=== $Title ==="
  Log ("CMD: {0} {1}" -f $FilePath, ($Arguments -join " "))
  try {
    $output = & $FilePath @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($null -ne $output) {
      $output | ForEach-Object {
        $text = $_.ToString()
        Write-Host $text
        Add-Content -Encoding UTF8 -Path $LogPath -Value $text
      }
    }
    Log "EXITCODE: $code"
    return @{ Code = $code; Output = ($output -join "`n") }
  } catch {
    Log ("ERROR: " + $_.Exception.Message)
    return @{ Code = -999; Output = $_.Exception.Message }
  }
}

function Add-ObjectLog {
  param([object]$Object)
  $text = $Object | Format-List * | Out-String
  Write-Host $text
  Add-Content -Encoding UTF8 -Path $LogPath -Value $text
}

Set-Content -Encoding UTF8 -Path $LogPath -Value ("[{0}] game-laptop-005 started." -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Log "IsAdmin: $isAdmin"
if (-not $isAdmin) {
  Log "STOP: This script must run as administrator."
  Read-Host "Run this script as administrator. Press Enter to close"
  exit 1
}

Log ""
Log "=== network profile before ==="
$profileBefore = Get-NetConnectionProfile -InterfaceAlias "WLAN" -ErrorAction SilentlyContinue
Add-ObjectLog $profileBefore
if (-not $profileBefore) {
  Log "STOP: WLAN profile not found."
  Read-Host "Press Enter to close"
  exit 1
}
if ($profileBefore.InterfaceAlias -ne "WLAN" -or $profileBefore.IPv4Connectivity -ne "Internet" -or $profileBefore.NetworkCategory -ne "Public") {
  Log "STOP: WLAN profile does not match required preconditions."
  Log ("InterfaceAlias={0}; IPv4Connectivity={1}; NetworkCategory={2}" -f $profileBefore.InterfaceAlias, $profileBefore.IPv4Connectivity, $profileBefore.NetworkCategory)
  Read-Host "Press Enter to close"
  exit 1
}

Log ""
Log "=== set WLAN profile private ==="
try {
  Set-NetConnectionProfile -InterfaceAlias "WLAN" -NetworkCategory Private
  Log "Set-NetConnectionProfile result: success"
} catch {
  Log ("Set-NetConnectionProfile result: ERROR " + $_.Exception.Message)
  Read-Host "Press Enter to close"
  exit 1
}

Log ""
Log "=== network profile after ==="
$profileAfter = Get-NetConnectionProfile -InterfaceAlias "WLAN" -ErrorAction SilentlyContinue
Add-ObjectLog $profileAfter
if (-not $profileAfter -or $profileAfter.NetworkCategory -ne "Private") {
  Log "STOP: WLAN profile is not Private after update."
  Read-Host "Press Enter to close"
  exit 1
}

$ssh = Run-Capture "WSL SSH status and IP" "wsl.exe" @("-d", "Ubuntu-24.04", "--", "bash", "-lc", "systemctl is-active ssh && ss -ltnp | grep ':22 ' && hostname -I")
$wslIp = $null
foreach ($line in ($ssh.Output -split "`n")) {
  if ($line -match "\b(172\.[0-9]+\.[0-9]+\.[0-9]+)\b") {
    $wslIp = $Matches[1]
  }
}
if (-not $wslIp) {
  Log "STOP: Could not detect WSL IP."
  Read-Host "Press Enter to close"
  exit 1
}
Log "Detected WSL IP: $wslIp"

Log ""
Log "=== IPv4 candidates ==="
$ipCandidates = Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.254.*" -and
    $_.PrefixOrigin -ne "WellKnown"
  } |
  Select-Object InterfaceAlias,IPAddress,PrefixLength,AddressState
$ipCandidates | Format-Table -AutoSize | Out-String | ForEach-Object {
  Write-Host $_
  Add-Content -Encoding UTF8 -Path $LogPath -Value $_
}

$wlanIpObj = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "WLAN" |
  Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.254.*" -and
    $_.AddressState -eq "Preferred"
  } |
  Select-Object -First 1
$lanIp = $wlanIpObj.IPAddress
if (-not $lanIp) {
  Log "STOP: Could not detect preferred WLAN LAN IP."
  Read-Host "Press Enter to close"
  exit 1
}
Log "Detected Windows LAN IP: $lanIp"

Run-Capture "delete existing SSH portproxy if present" "netsh.exe" @("interface", "portproxy", "delete", "v4tov4", "listenaddress=$lanIp", "listenport=2222") | Out-Null
$portproxyAdd = Run-Capture "add SSH portproxy $lanIp:2222 -> $wslIp:22" "netsh.exe" @("interface", "portproxy", "add", "v4tov4", "listenaddress=$lanIp", "listenport=2222", "connectaddress=$wslIp", "connectport=22")
Run-Capture "show portproxy" "netsh.exe" @("interface", "portproxy", "show", "v4tov4") | Out-Null
if ($portproxyAdd.Code -ne 0) {
  Log "STOP: SSH portproxy add failed."
  Read-Host "Press Enter to close"
  exit 1
}

$ruleName = "Codex WSL SSH LAN 2222"
Log ""
Log "=== remove existing firewall rule if present ==="
try {
  Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
  Log "Removed existing rule if present."
} catch {
  Log ("ERROR removing existing rule: " + $_.Exception.Message)
}

Log ""
Log "=== add firewall rule ==="
try {
  $rule = New-NetFirewallRule `
    -DisplayName $ruleName `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalAddress $lanIp `
    -LocalPort 2222 `
    -RemoteAddress LocalSubnet `
    -Profile Private `
    -Description "Allow LAN clients to SSH into WSL Ubuntu through Windows portproxy on TCP 2222"
  Add-ObjectLog $rule
  Log "Firewall rule add result: success"
} catch {
  Log ("Firewall rule add result: ERROR " + $_.Exception.Message)
  Read-Host "Press Enter to close"
  exit 1
}

Log ""
Log "=== firewall rule details ==="
try {
  Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Format-List DisplayName,Enabled,Profile,Direction,Action,Description | Out-String | ForEach-Object {
    Write-Host $_
    Add-Content -Encoding UTF8 -Path $LogPath -Value $_
  }
  Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue |
    Get-NetFirewallAddressFilter | Format-List LocalAddress,RemoteAddress | Out-String | ForEach-Object {
      Write-Host $_
      Add-Content -Encoding UTF8 -Path $LogPath -Value $_
    }
  Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue |
    Get-NetFirewallPortFilter | Format-List Protocol,LocalPort | Out-String | ForEach-Object {
      Write-Host $_
      Add-Content -Encoding UTF8 -Path $LogPath -Value $_
    }
} catch {
  Log ("ERROR reading firewall rule details: " + $_.Exception.Message)
}

Log ""
Log "=== Test-NetConnection ==="
try {
  $tnc = Test-NetConnection -ComputerName $lanIp -Port 2222
  Add-ObjectLog $tnc
} catch {
  Log ("Test-NetConnection ERROR: " + $_.Exception.Message)
}

Run-Capture "Windows SSH test" "ssh.exe" @("-p", "2222", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no", "jiaxi@$lanIp")

Log "Mac connection info:"
Log "HostName: $lanIp"
Log "Port: 2222"
Log "User: jiaxi"
Log "IdentityFile: ~/.ssh/id_ed25519_codex_dual_machine"
Log "Rollback executed: no"
Log "Finished. You can return to Codex."
Read-Host "Finished. Press Enter to close"
