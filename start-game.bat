@echo off
rem ────────────────────────────────────────
rem 1. Node.js サーバーをバックグラウンドで起動
rem ────────────────────────────────────────
echo [1/3] Starting Node.js server...
start "NodeServer" cmd /c "node server.js"
timeout /t 2 >nul

rem ────────────────────────────────────────
rem 2. ngrok トンネルをバックグラウンドで起動
rem ────────────────────────────────────────
echo [2/3] Starting ngrok tunnel on port 3000...
start "ngrok" cmd /c "ngrok http 3000"
timeout /t 2 >nul

rem ────────────────────────────────────────
rem 3. ngrok のローカル Web API から公開 URL を取得してクリップボードにコピー
rem ────────────────────────────────────────
echo [3/3] Retrieving public URL...
for /f "tokens=2 delims=: " %%A in ('curl -s http://127.0.0.1:4040/api/tunnels ^| findstr /i "https://"') do (
  set "NGROK_URL=%%A"
)
rem Windows のクリップボードにコピー
powershell -NoProfile -Command "Set-Clipboard '%NGROK_URL%'"
echo Public URL copied to clipboard:
echo    %NGROK_URL%

echo.
echo Press any key to stop services and exit.
pause >nul

rem ────────────────────────────────────────
rem 4. サーバーと ngrok を停止
rem ────────────────────────────────────────
echo Stopping services...
taskkill /FI "WINDOWTITLE eq NodeServer*" /T /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq ngrok*"     /T /F >nul 2>&1

echo Done.
