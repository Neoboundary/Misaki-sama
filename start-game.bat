@echo off
setlocal enabledelayedexpansion

rem ----------------------------------------------------
rem 1. Start Node.js server
rem ----------------------------------------------------
echo [1/3] Starting Node.js server on port 3000...
start "NodeServer" cmd /c "node server.js"
timeout /t 2 >nul

rem ----------------------------------------------------
rem 2. Start ngrok tunnel
rem ----------------------------------------------------
echo [2/3] Starting ngrok tunnel on port 3000...
start "ngrok" cmd /c "ngrok http 3000"
timeout /t 2 >nul

rem ----------------------------------------------------
rem 3. Retrieve public URL from ngrok API with retries
rem ----------------------------------------------------
echo [3/3] Retrieving public URL from ngrok API...
set "NGROK_URL="
for /l %%I in (1,1,10) do (
    for /f "tokens=2 delims=:" %%A in ('curl -s http://127.0.0.1:4040/api/tunnels ^| findstr /i public_url') do (
        set "urlPart=%%A"
        rem remove quotes and commas
        set "urlPart=!urlPart:\"=!"
        set "urlPart=!urlPart:,=!"
        rem trim spaces
        for /f "tokens=*" %%B in ("!urlPart!") do set "NGROK_URL=%%B"
    )
    if defined NGROK_URL goto got_url
    timeout /t 1 >nul
)
echo Failed to retrieve ngrok URL after multiple attempts. Ensure ngrok is running and API is accessible.
pause
endlocal
exit /b

:got_url

rem show and copy URL
echo Public URL: !NGROK_URL!
echo Copying URL to clipboard...
powershell -NoProfile -Command "Set-Clipboard '!NGROK_URL!'"
echo URL copied to clipboard.

echo.
echo Press any key to stop services and exit.
pause >nul

rem ----------------------------------------------------
rem 4. Stop services
rem ----------------------------------------------------
echo Stopping services...
taskkill /FI "WINDOWTITLE eq NodeServer*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq ngrok*"     /T /F >nul 2>&1

echo Done.
endlocal
