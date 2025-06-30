@echo off
rem start server
start "NodeServer" cmd /c "node server.js"
timeout /t 2 >nul

rem start ngrok tunnel
start "ngrok" cmd /c "ngrok http 3000"
timeout /t 2 >nul

rem retrieve public URL from ngrok API
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "(Invoke-RestMethod http://127.0.0.1:4040/api/tunnels).tunnels ^| Where-Object {$_.proto -eq 'https'} ^| Select-Object -ExpandProperty public_url"') do (
    set "NGROK_URL=%%A"
)
if not defined NGROK_URL (
    echo Failed to retrieve ngrok URL.
    pause
    exit /b
)
echo Public URL: %NGROK_URL%
rem copy to clipboard
powershell -NoProfile -Command "Set-Clipboard '%NGROK_URL%'"
echo URL copied to clipboard.

rem wait for key to exit
echo.
echo Press any key to stop services and exit.
pause >nul

rem stop services
taskkill /FI "WINDOWTITLE eq NodeServer*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq ngrok*"     /T /F >nul 2>&1
echo Done.
