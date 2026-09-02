@echo off
title Disable Silent Startup Auto-Check
cd /d "%~dp0"

echo Disabling silent startup auto-check...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "VenSyncAutoSetupManager" /f

echo.
echo Startup check disabled.
pause
