@echo off
echo Starting Node.js server and ngrok via PowerShell...
powershell.exe -NoExit -ExecutionPolicy Bypass -File "%~dp0start_server.ps1"
pause
