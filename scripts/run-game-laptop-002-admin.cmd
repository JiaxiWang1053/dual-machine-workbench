@echo off
set SCRIPT_DIR=%~dp0
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%game-laptop-002-wsl-proxy-admin.ps1"
