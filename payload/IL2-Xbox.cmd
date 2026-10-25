@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play-IL2-Xbox.ps1" %*
if errorlevel 1 pause