@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-robotis-regulatory.ps1" %*
exit /b %errorlevel%
