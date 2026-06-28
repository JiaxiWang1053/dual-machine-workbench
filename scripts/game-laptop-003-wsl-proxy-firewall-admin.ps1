$ErrorActionPreference = "Continue"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ReportDir = Join-Path $RepoRoot "reports"
$LogPath = Join-Path $ReportDir "game-laptop-003-wsl-proxy-firewall.log"
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

Set-Content -Encoding UTF8 -Path $LogPath -Value ("[{0}] game-laptop-003 started." -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

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
$natCidr = $null
foreach ($line in ($route.Output -split "`n")) {
  if (-not $hostIp -and $line -match "default\s+via\s+([0-9.]+)") {
    $hostIp = $Matches[1]
  }
  if (-not $natCidr -and $line -match "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+)\s+dev\s+eth0") {
    $natCidr = $Matches[1]
  }
}

if (-not $hostIp -or -not $natCidr) {
  Log "STOP: Could not detect WSL host IP or NAT CIDR from ip route output."
  Log "Detected hostIp=$hostIp natCidr=$natCidr"
  Read-Host "Press Enter to close"
  exit 1
}
Log "Detected WSL host IP: $hostIp"
Log "Detected WSL NAT CIDR: $natCidr"

Run-Capture "show portproxy before firewall" "netsh.exe" @("interface", "portproxy", "show", "v4tov4") | Out-Null
Run-Capture "netstat 7898 before firewall" "cmd.exe" @("/c", "netstat -ano | findstr 7898") | Out-Null

$ruleName = "Codex WSL Proxy 7898"
Log ""
Log "=== remove existing firewall rule if present ==="
try {
  $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
  if ($existing) {
    $existing | Format-List * | Out-String | ForEach-Object {
      Write-Host $_
      Add-Content -Encoding UTF8 -Path $LogPath -Value $_
    }
    Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    Log "Removed existing rule: $ruleName"
  } else {
    Log "No existing rule found."
  }
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
    -LocalAddress $hostIp `
    -LocalPort 7898 `
    -RemoteAddress $natCidr `
    -Profile Any `
    -Description "Allow WSL NAT clients to reach Windows portproxy 7898 for local Clash/Mihomo proxy only"
  $rule | Format-List * | Out-String | ForEach-Object {
    Write-Host $_
    Add-Content -Encoding UTF8 -Path $LogPath -Value $_
  }
  Log "Firewall rule add result: success"
} catch {
  Log ("Firewall rule add result: ERROR " + $_.Exception.Message)
}

Log ""
Log "=== firewall rule details ==="
try {
  Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Format-List * | Out-String | ForEach-Object {
    Write-Host $_
    Add-Content -Encoding UTF8 -Path $LogPath -Value $_
  }
  Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue |
    Get-NetFirewallAddressFilter | Format-List * | Out-String | ForEach-Object {
      Write-Host $_
      Add-Content -Encoding UTF8 -Path $LogPath -Value $_
    }
  Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue |
    Get-NetFirewallPortFilter | Format-List * | Out-String | ForEach-Object {
      Write-Host $_
      Add-Content -Encoding UTF8 -Path $LogPath -Value $_
    }
} catch {
  Log ("ERROR reading firewall rule details: " + $_.Exception.Message)
}

Run-Capture "WSL TCP test to portproxy" "wsl.exe" @("-d", "Ubuntu-24.04", "-u", "jiaxi", "--", "bash", "-lc", "timeout 5 bash -c '</dev/tcp/$hostIp/7898' && echo TCP_OK || echo TCP_FAIL") | Out-Null
$curl = Run-Capture "WSL curl GitHub through portproxy" "wsl.exe" @("-d", "Ubuntu-24.04", "-u", "jiaxi", "--", "bash", "-lc", "curl -I --connect-timeout 10 -x http://$hostIp`:7898 https://github.com")

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
  Run-Capture "proxy helper show" "wsl.exe" @("-d", "Ubuntu-24.04", "-u", "jiaxi", "--", "bash", "-lc", "source /home/jiaxi/bin/proxy show") | Out-Null
  Run-Capture "git ls-remote through WSL proxy" "wsl.exe" @("-d", "Ubuntu-24.04", "-u", "jiaxi", "--", "bash", "-lc", "source /home/jiaxi/bin/proxy on >/dev/null && git ls-remote https://github.com/JiaxiWang1053/dual-machine-workbench.git HEAD")
  Run-Capture "pip index versions torch through WSL proxy" "wsl.exe" @("-d", "Ubuntu-24.04", "-u", "jiaxi", "--", "bash", "-lc", "source /home/jiaxi/bin/proxy on >/dev/null && python3 -m pip index versions torch | head -n 20")
} else {
  Log "Proxy curl test failed; not creating helper script."
}

Log "Rollback executed: no"
Log "Finished. You can return to Codex."
Read-Host "Finished. Press Enter to close"
