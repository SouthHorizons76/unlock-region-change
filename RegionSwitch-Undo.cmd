@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RegionSwitch.ps1" -Undo %*
pause
