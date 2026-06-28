$ErrorActionPreference = "Continue"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ReportDir = Join-Path $RepoRoot "reports"
$LogPath = Join-Path $ReportDir "game-laptop-002-wsl-proxy.log"
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

Set-Content -Encoding UTF8 -Path $LogPath -Value ("[{0}] game-laptop-002 started." -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Log "IsAdmin: $isAdmin"
if (-not $isAdmin) {
  Log "STOP: This script must run as administrator."
  Read-Host "Run this script as administrator. Press Enter to close"
  exit 1
}

$route = Run-Capture "wsl ip route" "wsl.exe" @("-d", "Ubuntu-24.04", "--", "ip", "route")
$hostIp = $null
foreach ($line in ($route.Output -split "`n")) {
  if ($line -match "default\s+via\s+([0-9.]+)") {
    $hostIp = $Matches[1]
    break
  }
}

if (-not $hostIp) {
  Log "STOP: Could not detect WSL host IP from ip route output."
  Read-Host "Press Enter to close"
  exit 1
}
Log "Detected WSL host IP: $hostIp"

Run-Capture "delete existing portproxy for host ip 7898 if present" "netsh.exe" @("interface", "portproxy", "delete", "v4tov4", "listenaddress=$hostIp", "listenport=7898") | Out-Null
$add = Run-Capture "add portproxy $hostIp:7898 -> 127.0.0.1:7897" "netsh.exe" @("interface", "portproxy", "add", "v4tov4", "listenaddress=$hostIp", "listenport=7898", "connectaddress=127.0.0.1", "connectport=7897")
Run-Capture "show portproxy" "netsh.exe" @("interface", "portproxy", "show", "v4tov4") | Out-Null
Run-Capture "netstat 7898" "cmd.exe" @("/c", "netstat -ano | findstr 7898") | Out-Null

if ($add.Code -ne 0) {
  Log "STOP: portproxy add failed."
  Read-Host "Press Enter to close"
  exit 1
}

$curl = Run-Capture "WSL curl GitHub through portproxy" "wsl.exe" @("-d", "Ubuntu-24.04", "--", "bash", "-lc", "curl -I --connect-timeout 10 -x http://$hostIp`:7898 https://github.com")

if ($curl.Code -eq 0) {
  $proxyScript = @'
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
'@
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($proxyScript))
  Run-Capture "create WSL proxy helper" "wsl.exe" @("-d", "Ubuntu-24.04", "-u", "jiaxi", "--", "bash", "-lc", "echo $encoded | base64 -d | bash") | Out-Null
  Run-Capture "show WSL proxy helper" "wsl.exe" @("-d", "Ubuntu-24.04", "-u", "jiaxi", "--", "bash", "-lc", "source /home/jiaxi/bin/proxy show") | Out-Null
} else {
  Log "Proxy curl test failed; not creating helper script."
}

Log "Finished. You can return to Codex."
Read-Host "Finished. Press Enter to close"
