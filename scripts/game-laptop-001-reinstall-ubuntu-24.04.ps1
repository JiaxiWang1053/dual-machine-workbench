$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$LogPath = Join-Path $RepoRoot "reports\game-laptop-001-admin.log"
$Target = "D:\WSL\Ubuntu"

function Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line
}

function Run-Native {
    param(
        [string]$Name,
        [string]$FilePath,
        [string[]]$Arguments
    )
    Log ""
    Log "=== $Name ==="
    Log ("CMD: {0} {1}" -f $FilePath, ($Arguments -join " "))
    $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
    Log "EXITCODE: $($p.ExitCode)"
    return $p.ExitCode
}

function Stop-On-Fail {
    param([int]$Code, [string]$Message)
    if ($Code -ne 0) {
        Log "STOP: $Message"
        Read-Host "Failed. Press Enter to close"
        exit $Code
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "reports") | Out-Null
if (Test-Path $LogPath) {
    Remove-Item -LiteralPath $LogPath -Force
}

Log "Task game-laptop-001 started."
Log "RepoRoot: $RepoRoot"
Log "Target: $Target"
Log "User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Log "IsAdmin: $isAdmin"
if (-not $isAdmin) {
    Log "STOP: Not elevated."
    Read-Host "Not elevated. Press Enter to close"
    exit 10
}

Run-Native "wsl --list --verbose before" "wsl.exe" @("--list", "--verbose") | Out-Null
Run-Native "wsl --status before" "wsl.exe" @("--status") | Out-Null
Run-Native "wsl --list --online" "wsl.exe" @("--list", "--online") | Out-Null

if (Test-Path -LiteralPath $Target) {
    Log "Target exists before unregister. Listing top-level contents."
    Get-ChildItem -LiteralPath $Target -Force | ForEach-Object {
        Log ("ITEM: {0} {1} {2}" -f $_.FullName, $_.Mode, $_.Length)
    }
}

$code = Run-Native "wsl --terminate Ubuntu" "wsl.exe" @("--terminate", "Ubuntu")
if ($code -ne 0) {
    Log "WARN: terminate Ubuntu returned non-zero; continuing to unregister."
}

$code = Run-Native "wsl --unregister Ubuntu" "wsl.exe" @("--unregister", "Ubuntu")
Stop-On-Fail $code "wsl --unregister Ubuntu failed."

if (Test-Path -LiteralPath $Target) {
    Log "Removing old target directory only: $Target"
    Remove-Item -LiteralPath $Target -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null
Log "Created clean target directory: $Target"

$code = Run-Native "wsl --install -d Ubuntu-24.04 --location D:\WSL\Ubuntu" "wsl.exe" @("--install", "-d", "Ubuntu-24.04", "--location", $Target)
if ($code -ne 0) {
    Log "STOP: Ubuntu-24.04 install failed. No fallback method attempted."
    Read-Host "Ubuntu-24.04 install failed. Press Enter to close"
    exit 40
}

Log "Install command completed."
Run-Native "wsl --list --verbose after install" "wsl.exe" @("--list", "--verbose") | Out-Null
Log "If prompted to create a UNIX user, use username jiaxi and your own password."
Read-Host "If Ubuntu user creation is complete, press Enter to close"
