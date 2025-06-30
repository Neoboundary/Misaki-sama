rem 1. Node.js on
echo [1/3] Starting Node.js server...
start "nodeserver" cmd /c "node server.js"
timeout /t 2 >nul

rem 2. ngrok on
echo [2/3] Starting ngrok tunnel on port 3000...
cd C:\Users\nagar\downloads\ngrok-v3
start "ngrok" cmd /c "cd /d "C:\Users\nagar\Downloads\ngrok-v3" && .\ngrok http 3000"
timeout /t 2 >nul

rem 3. retrieve public URL from ngrok webapi
echo [3/3] Retrieving public URL
start "public_url" cmd /c "$urldata = curl.exe -s http://127.0.0.1:4040/api/tunnels"
if ($urldata -match 'https://[^"]*'){
  $public_url = $matches[0]
}

rem copy to clipboard
powershell -NoProfile -Command "Set-Clipboard '$public_url'"
echo Public URL copied to clipboard:
echo $public_url

echo.
echo Press any key to stop services and exit.
pause >nul

rem 4. stop local server and ngrok
echo Stopping services...
taskkill /FI "WINDOWTITLE eq NodeServer*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq ngrok*"     /T /F >nul 2>&1

echo Done.
