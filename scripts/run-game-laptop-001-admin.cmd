@echo off
set "SCRIPT=%~dp0game-laptop-001-reinstall-ubuntu-24.04.ps1"
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Please right-click this file and choose Run as administrator.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
echo.
echo Finished or stopped. You can return to Codex now.
echo.
pause
