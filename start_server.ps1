# --- start-server.ps1（置き換え）---

# スクリプト自身のディレクトリを取得し、作業ディレクトリにする
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 設定
$Port = 3000
$NgrokPath = "C:\Users\nagar\Downloads\ngrok-v3\ngrok.exe"

# [1/4] Nodeサーバー起動
Write-Host "[1/4] Starting Node.js server..."
$nodeProc = Start-Process -FilePath "node" -ArgumentList "server.js" -WorkingDirectory $ScriptDir -PassThru

# [2/4] ngrok起動
Write-Host "[2/4] Starting ngrok tunnel on port $Port..."
$ngrokProc = Start-Process -FilePath $NgrokPath -ArgumentList "http $Port" -WorkingDirectory $ScriptDir -PassThru

# [3/4] 公開URL取得（ngrokのローカルAPI）
Write-Host "[3/4] Retrieving public URL from ngrok API..."
Start-Sleep -Seconds 3
try {
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -ErrorAction Stop
    $url = ($resp.tunnels | Where-Object { $_.public_url -like "https:*" } | Select-Object -First 1).public_url
    if ($url) {
        Set-Clipboard $url
        Write-Host "Public URL copied to clipboard:"
        Write-Host $url
    } else {
        Write-Host "Error: Public URL not found."
    }
} catch {
    Write-Host "Error: Failed to retrieve ngrok URL. Is ngrok running?"
}

# [4/4] 終了待ち
Write-Host ""
Write-Host "Press any key to stop services and exit..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

# プロセス停止
Write-Host "Stopping services..."
if ($nodeProc -and !$nodeProc.HasExited) { Stop-Process -Id $nodeProc.Id -Force }
if ($ngrokProc -and !$ngrokProc.HasExited) { Stop-Process -Id $ngrokProc.Id -Force }
Write-Host "Done."
