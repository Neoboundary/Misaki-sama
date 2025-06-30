# Nodeサーバー起動
Write-Host "[1/3] Starting Node.js server..."
Start-Process -NoNewWindow -FilePath "node" -ArgumentList "server.js"

# ngrok起動
Write-Host "[2/3] Starting ngrok tunnel on port 3000..."
$ngrokPath = "C:\Users\nagar\Downloads\ngrok-v3\ngrok.exe"
Start-Process -NoNewWindow -FilePath $ngrokPath -ArgumentList "http 3000"

# 少し待機
Start-Sleep -Seconds 3

# ngrok APIからパブリックURL取得
Write-Host "[3/3] Retrieving public URL from ngrok API..."

try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -ErrorAction Stop
    $url = $response.tunnels[0].public_url

    if ($url) {
        # クリップボードにコピー
        Set-Clipboard $url
        Write-Host "Public URL copied to clipboard:"
        Write-Host $url
    } else {
        Write-Host "Error: Public URL not found in ngrok response."
    }
}
catch {
    Write-Host "Error: Failed to retrieve ngrok URL. Is ngrok running?"
}

# 停止待機
Write-Host ""
Write-Host "Press any key to stop services and exit..."
$x = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Nodeとngrokプロセスを終了
Write-Host "Stopping services..."

Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process ngrok -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "Done."
