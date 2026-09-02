@echo off
title Enable Silent Startup Auto-Check
cd /d "%~dp0"

echo Enabling silent startup auto-check (runs hidden on boot, checks/repairs Vencord, and auto-closes with 0 RAM)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0VencordAutoManager.ps1" -Startup

echo.
pause
