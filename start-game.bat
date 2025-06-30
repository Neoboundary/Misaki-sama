@echo off
setlocal enabledelayedexpansion

rem 1. Node.js on
echo [1/3] Starting Node.js server...
start "nodeserver" cmd /c "node server.js"
timeout /t 2 >nul

rem 2. ngrok on
echo [2/3] Starting ngrok tunnel on port 3000...
start "ngrok" cmd /c "cd /d C:\Users\nagar\Downloads\ngrok-v3 && .\ngrok http 3000"
timeout /t 2 >nul

rem 3. retrieve public URL from ngrok webapi
echo [3/3] Retrieving public URL...

for /f "usebackq delims=" %%A in (`powershell -Command "(Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels').tunnels | ForEach-Object { $_.public_url } | Select-Object -First 1"`) do (
    set "url=%%A"
)

rem copy to clipboard
powershell -NoProfile -Command "Set-Clipboard '!url!'"
echo Public URL copied to clipboard:
echo !url!

echo.
echo Press any key to stop services and exit.
pause >nul

rem 4. stop local server and ngrok
echo Stopping services...
taskkill /FI "WINDOWTITLE eq nodeserver" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq ngrok"      /T /F >nul 2>&1

echo Done.
