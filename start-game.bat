@echo off
REM ====================================================
REM start-game.bat（ANSI encodingで保存してください）
REM 1. Node.js サーバーをバックグラウンドで起動
REM ====================================================
echo [1/3] Starting Node.js server on port 3000...
start "NodeServer" cmd /c "node server.js"
timeout /t 2 >nul

REM ====================================================
REM 2. ngrok トンネルをバックグラウンドで起動
REM ====================================================
echo [2/3] Starting ngrok tunnel on port 3000...
start "ngrok" cmd /c "ngrok http 3000"
timeout /t 2 >nul

REM ====================================================
REM 3. ngrok のローカル API から HTTPS URL を取得してコピー
REM ====================================================
echo [3/3] Retrieving public URL via PowerShell...
REM PowerShell 経由で JSON をパースして public_url を抽出
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "(Invoke-RestMethod http://127.0.0.1:4040/api/tunnels).tunnels ^| Where-Object {$_.proto -eq 'https'} ^| Select-Object -ExpandProperty public_url"`) do (
    set "NGROK_URL=%%A"
)
if not defined NGROK_URL (
    echo Failed to retrieve ngrok URL.
    pause
    goto :EOF
)
echo Public URL: %NGROK_URL%
REM クリップボードにコピー
powershell -NoProfile -Command "Set-Clipboard '%NGROK_URL%'"
echo URL copied to clipboard.

echo.
echo Press any key to stop services and exit.
pause >nul

REM ====================================================
REM 4. サーバーと ngrok を停止
REM ====================================================
echo Stopping services...
taskkill /FI "WINDOWTITLE eq NodeServer*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq ngrok*" /T /F >nul 2>&1
echo Done.
